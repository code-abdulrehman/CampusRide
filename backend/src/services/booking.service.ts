import argon2 from 'argon2';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { toBooking } from '../common/utils/serializers.js';
import { prisma } from '../config/prisma.js';
import { createNotification } from './notification.service.js';
import { buildEvent, channelDate, EventTypes, rideChannel, routeChannel, userChannel } from '../realtime/events.js';
import { hub } from '../realtime/realtime-publisher.js';

export async function requestBooking(userId: string, rideId: string, seats: number) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  if (ride.driverId === userId) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'You cannot book your own ride');
  }
  if (ride.status !== 'OPEN') {
    throw new ApiError(409, ErrorCodes.RIDE_NOT_OPEN, 'Ride is no longer open');
  }
  if (seats > ride.availableSeats) {
    throw new ApiError(409, ErrorCodes.RIDE_FULL, 'Not enough seats available');
  }

  const existing = await prisma.booking.findFirst({
    where: {
      rideId,
      passengerId: userId,
      status: { in: ['REQUESTED', 'ACCEPTED', 'CHECKED_IN', 'RIDE_STARTED'] },
    },
  });
  if (existing) {
    throw new ApiError(409, ErrorCodes.BOOKING_ALREADY_EXISTS, 'You already have a booking on this ride');
  }

  const booking = await prisma.booking.create({
    data: {
      rideId,
      passengerId: userId,
      seats,
      status: 'REQUESTED',
    },
  });

  await createNotification({
    userId: ride.driverId,
    type: 'BOOKING_REQUEST',
    title: 'New booking request',
    body: `A student requested ${seats} seat${seats > 1 ? 's' : ''} on your ride to ${ride.destination}.`,
    data: { rideId, bookingId: booking.id },
  });

  hub.publish(
    rideChannel(rideId),
    buildEvent(EventTypes.BookingRequested, { booking: toBooking(booking), rideId }, ride.version),
  );

  return { booking: toBooking(booking), ride: { id: ride.id, status: ride.status } };
}

export interface AcceptResult {
  booking: ReturnType<typeof toBooking>;
  ride: { id: string; availableSeats: number; status: string; version: number };
}

export async function acceptBooking(userId: string, bookingId: string): Promise<AcceptResult> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { ride: true },
  });
  if (!booking) throw new ApiError(404, ErrorCodes.BOOKING_NOT_FOUND, 'Booking not found');
  if (booking.ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can accept bookings');
  }
  if (booking.status === 'ACCEPTED') {
    return {
      booking: toBooking(booking),
      ride: { id: booking.ride.id, availableSeats: booking.ride.availableSeats, status: booking.ride.status, version: booking.ride.version },
    };
  }
  if (booking.status !== 'REQUESTED') {
    throw new ApiError(409, ErrorCodes.BOOKING_INVALID_STATE, 'Only requested bookings can be accepted');
  }

  const result = await prisma.$transaction(async (tx) => {
    const seats = booking.seats;
    const rows = await tx.$executeRaw`
      UPDATE rides
      SET available_seats = available_seats - ${seats},
          version = version + 1,
          status = CASE
            WHEN available_seats - ${seats} <= 0 THEN 'FULL'::"RideStatus"
            ELSE status
          END,
          updated_at = now()
      WHERE id = ${booking.rideId} AND status = 'OPEN' AND available_seats >= ${seats}
    `;
    if (rows === 0) {
      throw new ApiError(409, ErrorCodes.RIDE_FULL, 'Ride is full or no longer open');
    }
    const checkinPinHash = await argon2.hash(booking.ride.ridePin, { type: argon2.argon2id });
    const updated = await tx.booking.update({
      where: { id: bookingId },
      data: { status: 'ACCEPTED', acceptedAt: new Date(), checkinPinHash },
    });
    return updated;
  });

  const updatedRide = await prisma.ride.findUnique({
    where: { id: booking.rideId },
    select: { id: true, availableSeats: true, status: true, version: true },
  });

  await createNotification({
    userId: booking.passengerId,
    type: 'BOOKING_ACCEPTED',
    title: 'Booking accepted',
    body: `Your seat on the ride to ${booking.ride.destination} was accepted.`,
    data: { rideId: booking.rideId, bookingId },
  });

  hub.publish(
    userChannel(booking.passengerId),
    buildEvent(EventTypes.BookingAccepted, { booking: toBooking(result), rideId: booking.rideId }),
  );
  if (updatedRide) {
    hub.publish(
      rideChannel(booking.rideId),
      buildEvent(
        EventTypes.RideSeatsUpdated,
        { rideId: booking.rideId, availableSeats: updatedRide.availableSeats },
        updatedRide.version,
      ),
    );
    hub.publish(
      rideChannel(booking.rideId),
      buildEvent(EventTypes.BookingAccepted, { booking: toBooking(result), rideId: booking.rideId }),
    );
    hub.publish(
      routeChannel(booking.ride.originCampusId, booking.ride.destinationCampusId, channelDate(booking.ride.departureAt)),
      buildEvent(
        EventTypes.RideSeatsUpdated,
        { rideId: booking.rideId, availableSeats: updatedRide.availableSeats },
        updatedRide.version,
      ),
    );
  }

  return {
    booking: toBooking(result),
    ride: updatedRide ?? { id: booking.rideId, availableSeats: booking.ride.availableSeats, status: booking.ride.status, version: booking.ride.version },
  };
}

export async function rejectBooking(userId: string, bookingId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { ride: true },
  });
  if (!booking) throw new ApiError(404, ErrorCodes.BOOKING_NOT_FOUND, 'Booking not found');
  if (booking.ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can reject bookings');
  }
  if (booking.status === 'REJECTED') return { booking: toBooking(booking) };
  if (booking.status !== 'REQUESTED') {
    throw new ApiError(409, ErrorCodes.BOOKING_INVALID_STATE, 'Only requested bookings can be rejected');
  }

  const updated = await prisma.booking.update({
    where: { id: bookingId },
    data: { status: 'REJECTED', rejectedAt: new Date() },
  });

  await createNotification({
    userId: booking.passengerId,
    type: 'BOOKING_REJECTED',
    title: 'Booking rejected',
    body: `Your booking request for the ride to ${booking.ride.destination} was declined.`,
    data: { rideId: booking.rideId, bookingId },
  });
  hub.publish(
    userChannel(booking.passengerId),
    buildEvent(EventTypes.BookingRejected, { booking: toBooking(updated), rideId: booking.rideId }, booking.ride.version),
  );

  return { booking: toBooking(updated) };
}

export async function cancelBooking(userId: string, bookingId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { ride: true },
  });
  if (!booking) throw new ApiError(404, ErrorCodes.BOOKING_NOT_FOUND, 'Booking not found');
  const isPassenger = booking.passengerId === userId;
  const isDriver = booking.ride.driverId === userId;
  if (!isPassenger && !isDriver) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Not a ride participant');
  }
  if (booking.status === 'CANCELLED') return { booking: toBooking(booking), seatRestored: false };
  if (!['REQUESTED', 'ACCEPTED'].includes(booking.status)) {
    throw new ApiError(409, ErrorCodes.BOOKING_INVALID_STATE, 'This booking cannot be cancelled');
  }

  const seatWasAccepted = booking.status === 'ACCEPTED';
  const canRestore = seatWasAccepted && ['OPEN', 'FULL'].includes(booking.ride.status);

  const updated = await prisma.$transaction(async (tx) => {
    if (canRestore) {
      const rows = await tx.$executeRaw`
        UPDATE rides
        SET available_seats = available_seats + ${booking.seats},
            version = version + 1,
            status = 'OPEN'::"RideStatus",
            updated_at = now()
        WHERE id = ${booking.rideId}
      `;
      void rows;
    }
    return tx.booking.update({
      where: { id: bookingId },
      data: { status: 'CANCELLED', cancelledAt: new Date() },
    });
  });

  const otherUserId = isPassenger ? booking.ride.driverId : booking.passengerId;
  await createNotification({
    userId: otherUserId,
    type: 'BOOKING_CANCELLED',
    title: 'Booking cancelled',
    body: isPassenger
      ? 'A passenger cancelled their booking on your ride.'
      : 'The driver cancelled your booking.',
    data: { rideId: booking.rideId, bookingId },
  });

  hub.publish(
    userChannel(otherUserId),
    buildEvent(EventTypes.BookingCancelled, { booking: toBooking(updated), rideId: booking.rideId }),
  );

  if (canRestore) {
    await publishSeatUpdate(booking.rideId);
  }

  return { booking: toBooking(updated), seatRestored: canRestore };
}

async function publishSeatUpdate(rideId: string): Promise<void> {
  const ride = await prisma.ride.findUnique({
    where: { id: rideId },
    select: {
      id: true,
      availableSeats: true,
      version: true,
      originCampusId: true,
      destinationCampusId: true,
      departureAt: true,
    },
  });
  if (!ride) return;
  hub.publish(
    rideChannel(rideId),
    buildEvent(EventTypes.RideSeatsUpdated, { rideId, availableSeats: ride.availableSeats }, ride.version),
  );
  hub.publish(
    routeChannel(ride.originCampusId, ride.destinationCampusId, channelDate(ride.departureAt)),
    buildEvent(EventTypes.RideSeatsUpdated, { rideId, availableSeats: ride.availableSeats }, ride.version),
  );
}

export async function checkinBooking(userId: string, bookingId: string, pin: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { ride: true },
  });
  if (!booking) throw new ApiError(404, ErrorCodes.BOOKING_NOT_FOUND, 'Booking not found');
  if (booking.ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can check in passengers');
  }
  if (booking.status !== 'ACCEPTED' && booking.status !== 'CHECKED_IN') {
    throw new ApiError(409, ErrorCodes.BOOKING_INVALID_STATE, 'Only accepted bookings can be checked in');
  }
  if (!booking.checkinPinHash) {
    throw new ApiError(409, ErrorCodes.BOOKING_INVALID_STATE, 'No check-in PIN was issued');
  }
  const valid = await argon2.verify(booking.checkinPinHash, pin);
  if (!valid) {
    throw new ApiError(400, ErrorCodes.INVALID_PIN, 'Incorrect check-in PIN');
  }
  if (booking.status === 'CHECKED_IN') return { booking: toBooking(booking) };

  const updated = await prisma.booking.update({
    where: { id: bookingId },
    data: { status: 'CHECKED_IN', checkedInAt: new Date() },
  });

  await createNotification({
    userId: booking.passengerId,
    type: 'BOOKING_ACCEPTED',
    title: 'Checked in',
    body: 'The driver checked you in for your ride.',
    data: { rideId: booking.rideId, bookingId },
  });
  hub.publish(
    rideChannel(booking.rideId),
    buildEvent(EventTypes.BookingCheckedIn, { booking: toBooking(updated), rideId: booking.rideId }, booking.ride.version),
  );

  return { booking: toBooking(updated) };
}

export async function noShowBooking(userId: string, bookingId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { ride: true },
  });
  if (!booking) throw new ApiError(404, ErrorCodes.BOOKING_NOT_FOUND, 'Booking not found');
  if (booking.ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can mark no-shows');
  }
  if (!['ACCEPTED', 'CHECKED_IN', 'RIDE_STARTED'].includes(booking.status)) {
    throw new ApiError(409, ErrorCodes.BOOKING_INVALID_STATE, 'Booking cannot be marked as a no-show');
  }
  if (booking.status === 'NO_SHOW') return { booking: toBooking(booking) };

  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.booking.update({
      where: { id: bookingId },
      data: { status: 'NO_SHOW', noShowAt: new Date() },
    });
    await tx.user.update({
      where: { id: booking.passengerId },
      data: { noShowCount: { increment: 1 } },
    });
    return result;
  });

  await createNotification({
    userId: booking.passengerId,
    type: 'BOOKING_NO_SHOW',
    title: 'Marked as no-show',
    body: 'The driver marked you as a no-show for this ride.',
    data: { rideId: booking.rideId, bookingId },
  });

  return { booking: toBooking(updated) };
}

export async function getBooking(userId: string, bookingId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      ride: { include: { driver: true, vehicle: true } },
      passenger: true,
    },
  });
  if (!booking) throw new ApiError(404, ErrorCodes.BOOKING_NOT_FOUND, 'Booking not found');
  const isDriver = booking.ride.driverId === userId;
  const isPassenger = booking.passengerId === userId;
  if (!isDriver && !isPassenger) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Not a ride participant');
  }
  return {
    booking: toBooking(booking),
    ride: {
      id: booking.ride.id,
      origin: booking.ride.origin,
      destination: booking.ride.destination,
      departureAt: booking.ride.departureAt,
      status: booking.ride.status,
      ridePin: isDriver ? booking.ride.ridePin : undefined,
    },
    driver: {
      id: booking.ride.driver.id,
      fullName: booking.ride.driver.fullName,
      avatarKey: booking.ride.driver.avatarKey,
      ratingAverage: booking.ride.driver.ratingAverage,
    },
    vehicle: {
      id: booking.ride.vehicle.id,
      company: booking.ride.vehicle.company,
      model: booking.ride.vehicle.model,
      color: booking.ride.vehicle.color,
      registrationNumber: booking.ride.vehicle.registrationNumber,
    },
  };
}

export async function myBookings(userId: string) {
  const bookings = await prisma.booking.findMany({
    where: { passengerId: userId },
    include: {
      ride: {
        include: {
          driver: {
            select: {
              id: true,
              fullName: true,
              avatarKey: true,
              ratingAverage: true,
            },
          },
          vehicle: {
            select: {
              id: true,
              company: true,
              model: true,
              color: true,
            },
          },
        },
      },
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });
  return bookings.map((b) => ({
    ...toBooking(b),
    ride: {
      id: b.ride.id,
      origin: b.ride.origin,
      destination: b.ride.destination,
      departureAt: b.ride.departureAt,
      status: b.ride.status,
      pricePerSeat: b.ride.pricePerSeat,
      driver: b.ride.driver,
      vehicle: b.ride.vehicle,
    },
  }));
}

export async function listRideBookings(userId: string, rideId: string) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  if (ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can list bookings');
  }
  const bookings = await prisma.booking.findMany({
    where: { rideId },
    include: {
      passenger: {
        select: {
          id: true,
          fullName: true,
          avatarKey: true,
          studentId: true,
          ratingAverage: true,
        },
      },
    },
    orderBy: { requestedAt: 'asc' },
  });
  return bookings.map((b) => ({ ...toBooking(b), passenger: b.passenger }));
}