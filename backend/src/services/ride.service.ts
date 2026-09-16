import { RideStatus } from '@prisma/client';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { toBooking, toPublicUser, toRide, toVehicle } from '../common/utils/serializers.js';
import { prisma } from '../config/prisma.js';
import { createNotification } from './notification.service.js';
import { scoreRide, type ScoreableRide } from './matching.service.js';
import { channelDate, buildEvent, EventTypes, rideChannel, routeChannel } from '../realtime/events.js';
import { hub } from '../realtime/realtime-publisher.js';
import { logAudit } from '../common/utils/audit.js';

export interface CreateRideInput {
  vehicleId: string;
  originCampusId: string;
  destinationCampusId: string;
  origin: string;
  destination: string;
  departureAt: Date;
  expectedArrivalAt?: Date;
  availableSeats: number;
  pricePerSeat: number;
  pickupRadiusKm?: number;
  maxDetourMinutes?: number;
  conditions?: string[];
  notes?: string;
  recurring?: boolean;
  recurringDays?: number[];
}

export interface RideWithDriver extends ScoreableRide {
  driverId: string;
}

async function generateRidePin(): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const pin = String(1000 + Math.floor(Math.random() * 9000));
    const existing = await prisma.ride.findUnique({ where: { ridePin: pin } });
    if (!existing) return pin;
  }
  throw new ApiError(500, ErrorCodes.INTERNAL, 'Could not generate a unique ride PIN');
}

export async function createRide(userId: string, input: CreateRideInput) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'User not found');
  if (user.driverVerified !== 'VERIFIED') {
    throw new ApiError(403, ErrorCodes.DRIVER_NOT_VERIFIED, 'Driver verification required');
  }

  const vehicle = await prisma.vehicle.findUnique({ where: { id: input.vehicleId } });
  if (!vehicle || vehicle.ownerId !== userId) {
    throw new ApiError(404, ErrorCodes.VEHICLE_NOT_FOUND, 'Vehicle not found');
  }
  if (vehicle.verificationStatus !== 'VERIFIED' || !vehicle.active) {
    throw new ApiError(403, ErrorCodes.VEHICLE_NOT_VERIFIED, 'Vehicle verification required');
  }

  const [fromCampus, toCampus] = await Promise.all([
    prisma.campus.findFirst({
      where: { id: input.originCampusId, active: true },
    }),
    prisma.campus.findFirst({
      where: { id: input.destinationCampusId, active: true },
    }),
  ]);
  if (!fromCampus || !toCampus) {
    throw new ApiError(400, ErrorCodes.CAMPUS_NOT_FOUND, 'Campus not found');
  }
  if (fromCampus.id === toCampus.id) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'Origin and destination campuses must differ');
  }
  if (input.departureAt.getTime() <= Date.now()) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'Departure time must be in the future');
  }
  const expected = input.expectedArrivalAt ?? new Date(input.departureAt.getTime() + 45 * 60_000);
  if (expected.getTime() <= input.departureAt.getTime()) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'Expected arrival must be after departure');
  }

  const ridePin = await generateRidePin();
  const ride = await prisma.ride.create({
    data: {
      driverId: userId,
      vehicleId: input.vehicleId,
      origin: input.origin,
      destination: input.destination,
      originCampusId: input.originCampusId,
      destinationCampusId: input.destinationCampusId,
      departureAt: input.departureAt,
      expectedArrivalAt: expected,
      availableSeats: input.availableSeats,
      pricePerSeat: input.pricePerSeat,
      pickupRadiusKm: input.pickupRadiusKm ?? 2,
      maxDetourMinutes: input.maxDetourMinutes ?? 30,
      conditions: input.conditions ?? [],
      notes: input.notes ?? null,
      recurring: input.recurring ?? false,
      recurringDays: input.recurringDays ?? [],
      ridePin,
      status: RideStatus.OPEN,
    },
  });

  hub.publish(
    routeChannel(input.originCampusId, input.destinationCampusId, channelDate(input.departureAt)),
    buildEvent(EventTypes.RideCreated, { ride: toRide(ride), driver: toPublicUser(user) }, ride.version),
  );

  const matchingRequests = await findMatchingRideRequests(ride);
  await Promise.all(
    matchingRequests.map((r) =>
      createNotification({
        userId: r.studentId,
        type: 'NEW_MATCH',
        title: 'New matching ride',
        body: `A ride from ${ride.origin} to ${ride.destination} matches your request.`,
        data: { rideId: ride.id, rideRequestId: r.id, matchScore: r.matchScore },
      }),
    ),
  );

  return { ride: toRide(ride), driver: toPublicUser(user) };
}

export interface SearchRideParams {
  fromCampusId: string;
  toCampusId: string;
  date: string;
  seats: number;
  startTime?: string;
  endTime?: string;
  maxBudget?: number;
  page?: number;
  pageSize?: number;
}

export async function searchRides(params: SearchRideParams) {
  const date = new Date(params.date + 'T00:00:00.000Z');
  const endOfDay = new Date(date.getTime() + 86_400_000);

  const [rides, total] = await Promise.all([
    prisma.ride.findMany({
      where: {
        originCampusId: params.fromCampusId,
        destinationCampusId: params.toCampusId,
        status: RideStatus.OPEN,
        availableSeats: { gte: params.seats },
        departureAt: { gte: date, lt: endOfDay },
      },
      include: {
        driver: {
          select: {
            id: true,
            fullName: true,
            avatarKey: true,
            ratingAverage: true,
            completedRidesCount: true,
            cancellationCount: true,
          },
        },
        vehicle: {
          select: {
            id: true,
            vehicleType: true,
            company: true,
            model: true,
            color: true,
            registrationNumber: true,
          },
        },
      },
      orderBy: { departureAt: 'asc' },
      skip: ((params.page ?? 1) - 1) * (params.pageSize ?? 20),
      take: params.pageSize ?? 20,
    }),
    prisma.ride.count({
      where: {
        originCampusId: params.fromCampusId,
        destinationCampusId: params.toCampusId,
        status: RideStatus.OPEN,
        availableSeats: { gte: params.seats },
        departureAt: { gte: date, lt: endOfDay },
      },
    }),
  ]);

  const scorable: RideWithDriver[] = rides.map((r) => ({
    driverId: r.driverId,
    originCampusId: r.originCampusId,
    destinationCampusId: r.destinationCampusId,
    departureAt: r.departureAt,
    pricePerSeat: r.pricePerSeat,
    pickupRadiusKm: r.pickupRadiusKm,
    ratingAverage: r.driver.ratingAverage,
    completedRidesCount: r.driver.completedRidesCount,
    cancellationCount: r.driver.cancellationCount,
  }));

  const items = rides.map((r, i) => ({
    ride: toRide(r),
    driver: r.driver,
    vehicle: r.vehicle,
    match: scoreRide(scorable[i], {
      ...params,
    }),
  })).sort((a, b) => b.match.matchScore - a.match.matchScore);

  return { items, total, page: params.page ?? 1, pageSize: params.pageSize ?? 20 };
}

export async function myRides(userId: string) {
  const rides = await prisma.ride.findMany({
    where: { driverId: userId },
    orderBy: { departureAt: 'desc' },
    take: 50,
  });
  return rides.map(toRide);
}

export async function getRide(rideId: string, userId: string) {
  const ride = await prisma.ride.findUnique({
    where: { id: rideId },
    include: {
      driver: {
        select: {
          id: true,
          fullName: true,
          email: true,
          studentId: true,
          avatarKey: true,
          ratingAverage: true,
          completedRidesCount: true,
          cancellationCount: true,
          createdAt: true,
        },
      },
      vehicle: true,
      bookings: {
        where: { passengerId: userId },
        take: 1,
      },
    },
  });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');

  const isDriver = ride.driverId === userId;
  const bookings = isDriver
    ? await prisma.booking.findMany({
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
      })
    : await prisma.booking.findMany({
        where: { rideId, passengerId: userId },
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
      });

  return {
    ride: toRide(ride),
    driver: {
      id: ride.driver.id,
      fullName: ride.driver.fullName,
      email: ride.driver.email,
      studentId: ride.driver.studentId,
      avatarKey: ride.driver.avatarKey,
      ratingAverage: ride.driver.ratingAverage,
      completedRidesCount: ride.driver.completedRidesCount,
      cancellationCount: ride.driver.cancellationCount,
      createdAt: ride.driver.createdAt,
    },
    vehicle: toVehicle(ride.vehicle),
    isDriver,
    myBooking: bookings.find((b) => b.passengerId === userId) ?? null,
    bookings: isDriver ? bookings.map((b) => ({ ...toBooking(b), passenger: b.passenger })) : [],
  };
}

export interface UpdateRideInput {
  departureAt?: Date;
  expectedArrivalAt?: Date;
  pricePerSeat?: number;
  availableSeats?: number;
  pickupRadiusKm?: number;
  maxDetourMinutes?: number;
  conditions?: string[];
  notes?: string | null;
}

export async function updateRide(userId: string, rideId: string, input: UpdateRideInput) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  if (ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can manage this ride');
  }
  if (ride.status !== 'OPEN') {
    throw new ApiError(409, ErrorCodes.RIDE_INVALID_STATE, 'Only open rides can be edited');
  }

  const data: Record<string, unknown> = {};
  if (input.departureAt !== undefined) {
    if (input.departureAt.getTime() <= Date.now()) {
      throw new ApiError(400, ErrorCodes.VALIDATION, 'Departure time must be in the future');
    }
    data.departureAt = input.departureAt;
  }
  if (input.expectedArrivalAt !== undefined) data.expectedArrivalAt = input.expectedArrivalAt;
  if (input.pricePerSeat !== undefined) {
    if (input.pricePerSeat < 0) throw new ApiError(400, ErrorCodes.VALIDATION, 'Price cannot be negative');
    data.pricePerSeat = input.pricePerSeat;
  }
  if (input.availableSeats !== undefined) {
    const booked = await prisma.booking.aggregate({
      where: {
        rideId,
        status: { in: ['ACCEPTED', 'CHECKED_IN', 'RIDE_STARTED'] },
      },
      _sum: { seats: true },
    });
    const taken = booked._sum.seats ?? 0;
    if (input.availableSeats < taken) {
      throw new ApiError(400, ErrorCodes.VALIDATION, `Cannot reduce below ${taken} booked seats`);
    }
    data.availableSeats = input.availableSeats;
  }
  if (input.pickupRadiusKm !== undefined) data.pickupRadiusKm = input.pickupRadiusKm;
  if (input.maxDetourMinutes !== undefined) data.maxDetourMinutes = input.maxDetourMinutes;
  if (input.conditions !== undefined) data.conditions = input.conditions;
  if (input.notes !== undefined) data.notes = input.notes;

  if (Object.keys(data).length === 0) return toRide(ride);

  const updated = await prisma.ride.update({
    where: { id: rideId },
    data: { ...data, version: { increment: 1 } },
  });

  hub.publish(
    routeChannel(updated.originCampusId, updated.destinationCampusId, channelDate(updated.departureAt)),
    buildEvent(EventTypes.RideUpdated, { ride: toRide(updated) }, updated.version),
  );

  return toRide(updated);
}

export async function cancelRide(userId: string, rideId: string) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  if (ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can manage this ride');
  }
  if (!['OPEN', 'FULL'].includes(ride.status)) {
    throw new ApiError(409, ErrorCodes.RIDE_INVALID_STATE, 'Only open or full rides can be cancelled');
  }

  const updated = await prisma.$transaction(async (tx) => {
    await tx.booking.updateMany({
      where: { rideId, status: 'REQUESTED' },
      data: { status: 'REJECTED', rejectedAt: new Date() },
    });
    const accepted = await tx.booking.findMany({
      where: { rideId, status: { in: ['ACCEPTED', 'CHECKED_IN'] } },
      select: { id: true, passengerId: true },
    });
    await tx.booking.updateMany({
      where: { id: { in: accepted.map((b) => b.id) } },
      data: { status: 'CANCELLED', cancelledAt: new Date() },
    });
    const rideUpdated = await tx.ride.update({
      where: { id: rideId },
      data: { status: 'CANCELLED', version: { increment: 1 } },
    });
    return { rideUpdated, bookedPassengers: accepted.map((b) => b.passengerId) };
  });

  await logAudit(userId, 'CANCEL_RIDE', 'ride', rideId);
  hub.publish(
    rideChannel(rideId),
    buildEvent(EventTypes.RideCancelled, { rideId }, updated.rideUpdated.version),
  );
  hub.publish(
    routeChannel(updated.rideUpdated.originCampusId, updated.rideUpdated.destinationCampusId, channelDate(updated.rideUpdated.departureAt)),
    buildEvent(EventTypes.RideCancelled, { rideId }, updated.rideUpdated.version),
  );
  await Promise.all(
    updated.bookedPassengers.map((passengerId) =>
      createNotification({
        userId: passengerId,
        type: 'BOOKING_CANCELLED',
        title: 'Ride cancelled',
        body: `Your booked ride from ${updated.rideUpdated.origin} was cancelled by the driver.`,
        data: { rideId },
      }),
    ),
  );
  return { ride: toRide(updated.rideUpdated) };
}

export async function startRide(userId: string, rideId: string, checkin: boolean) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  if (ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can manage this ride');
  }
  if (!['OPEN', 'FULL'].includes(ride.status)) {
    throw new ApiError(409, ErrorCodes.RIDE_INVALID_STATE, 'Only open or full rides can be started');
  }

  const passengers = await prisma.booking.findMany({
    where: { rideId, status: { in: ['ACCEPTED', 'CHECKED_IN'] } },
    select: { passengerId: true },
  });

  const updated = await prisma.ride.update({
    where: { id: rideId },
    data: { status: 'STARTED', version: { increment: 1 } },
  });

  if (checkin) {
    await prisma.booking.updateMany({
      where: { rideId, status: 'ACCEPTED' },
      data: { status: 'CHECKED_IN', checkedInAt: new Date() },
    });
  }

  hub.publish(rideChannel(rideId), buildEvent(EventTypes.RideStarted, { rideId }, updated.version));
  await Promise.all(
    passengers.map((p) =>
      createNotification({
        userId: p.passengerId,
        type: 'RIDE_STARTED',
        title: 'Ride started',
        body: `Your ride from ${updated.origin} to ${updated.destination} has started.`,
        data: { rideId },
      }),
    ),
  );
  return { ride: toRide(updated) };
}

export async function completeRide(userId: string, rideId: string) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  if (ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.FORBIDDEN, 'Only the ride driver can manage this ride');
  }
  if (ride.status !== 'STARTED') {
    throw new ApiError(409, ErrorCodes.RIDE_INVALID_STATE, 'Only started rides can be completed');
  }

  const updated = await prisma.$transaction(async (tx) => {
    const passengers = await tx.booking.findMany({
      where: { rideId, status: { in: ['CHECKED_IN', 'RIDE_STARTED', 'ACCEPTED'] } },
      select: { id: true, passengerId: true },
    });
    await tx.booking.updateMany({
      where: { id: { in: passengers.map((p) => p.id) } },
      data: { status: 'COMPLETED', completedAt: new Date() },
    });
    const rideUpdated = await tx.ride.update({
      where: { id: rideId },
      data: { status: 'COMPLETED', version: { increment: 1 } },
    });
    await tx.user.update({
      where: { id: userId },
      data: { completedRidesCount: { increment: 1 } },
    });
    await tx.user.updateMany({
      where: { id: { in: passengers.map((p) => p.passengerId) } },
      data: { completedRidesCount: { increment: 1 } },
    });
    return { rideUpdated, passengerIds: passengers.map((p) => p.passengerId) };
  });

  hub.publish(rideChannel(rideId), buildEvent(EventTypes.RideCompleted, { rideId }, updated.rideUpdated.version));
  await Promise.all(
    updated.passengerIds.map((passengerId) =>
      createNotification({
        userId: passengerId,
        type: 'RIDE_COMPLETED',
        title: 'Ride completed',
        body: `Ride from ${updated.rideUpdated.origin} to ${updated.rideUpdated.destination} completed.`,
        data: { rideId },
      }),
    ),
  );
  return { ride: toRide(updated.rideUpdated) };
}

async function findMatchingRideRequests(ride: {
  originCampusId: string;
  destinationCampusId: string;
  departureAt: Date;
  pricePerSeat: number;
  pickupRadiusKm: number;
  availableSeats: number;
}): Promise<Array<{ id: string; studentId: string; matchScore: number }>> {
  const windowStart = new Date(ride.departureAt.getTime() - 3_600_000);
  const windowEnd = new Date(ride.departureAt.getTime() + 3_600_000);

  const requests = await prisma.rideRequest.findMany({
    where: {
      status: 'OPEN',
      originCampusId: ride.originCampusId,
      destinationCampusId: ride.destinationCampusId,
      requiredSeats: { lte: ride.availableSeats },
      earliestDeparture: { lte: windowEnd },
      latestDeparture: { gte: windowStart },
    },
  });

  return requests
    .map((r) => ({
      id: r.id,
      studentId: r.studentId,
      matchScore: scoreRide(
        {
          originCampusId: ride.originCampusId,
          destinationCampusId: ride.destinationCampusId,
          departureAt: ride.departureAt,
          pricePerSeat: ride.pricePerSeat,
          pickupRadiusKm: ride.pickupRadiusKm,
          ratingAverage: 0,
          completedRidesCount: 0,
          cancellationCount: 0,
        },
        {
          fromCampusId: r.originCampusId,
          toCampusId: r.destinationCampusId,
          seats: r.requiredSeats,
          startTime: fmtTime(r.earliestDeparture),
          endTime: fmtTime(r.latestDeparture),
          maxBudget: r.maxBudget ?? undefined,
        },
      ).matchScore,
    }))
    .filter((r) => r.matchScore >= 40);
}

function fmtTime(date: Date): string {
  return date.toISOString().slice(11, 16);
}