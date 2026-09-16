import type { Booking, Campus, Ride, User, Vehicle } from '@prisma/client';

export function toPublicUser(user: User) {
  return {
    id: user.id,
    email: user.email,
    fullName: user.fullName,
    studentId: user.studentId,
    avatarKey: user.avatarKey,
    mainCampusId: user.mainCampusId,
    role: user.role,
    studentVerified: user.studentVerified,
    driverVerified: user.driverVerified,
    accountStatus: user.accountStatus,
    ratingAverage: user.ratingAverage,
    completedRidesCount: user.completedRidesCount,
    cancellationCount: user.cancellationCount,
    noShowCount: user.noShowCount,
    createdAt: user.createdAt,
  };
}

export function toCampus(campus: Campus) {
  return {
    id: campus.id,
    name: campus.name,
    code: campus.code,
    address: campus.address,
    latitude: campus.latitude,
    longitude: campus.longitude,
    securityContact: campus.securityContact,
    openingHour: campus.openingHour,
    closingHour: campus.closingHour,
  };
}

export function toVehicle(vehicle: Vehicle) {
  return {
    id: vehicle.id,
    ownerId: vehicle.ownerId,
    vehicleType: vehicle.vehicleType,
    company: vehicle.company,
    model: vehicle.model,
    year: vehicle.year,
    color: vehicle.color,
    registrationNumber: vehicle.registrationNumber,
    totalSeats: vehicle.totalSeats,
    passengerCapacity: vehicle.passengerCapacity,
    verificationStatus: vehicle.verificationStatus,
    active: vehicle.active,
  };
}

export function toRide(ride: Ride) {
  return {
    id: ride.id,
    driverId: ride.driverId,
    vehicleId: ride.vehicleId,
    origin: ride.origin,
    destination: ride.destination,
    originCampusId: ride.originCampusId,
    destinationCampusId: ride.destinationCampusId,
    departureAt: ride.departureAt,
    expectedArrivalAt: ride.expectedArrivalAt,
    availableSeats: ride.availableSeats,
    pricePerSeat: ride.pricePerSeat,
    pickupRadiusKm: ride.pickupRadiusKm,
    maxDetourMinutes: ride.maxDetourMinutes,
    conditions: ride.conditions,
    notes: ride.notes,
    recurring: ride.recurring,
    recurringDays: ride.recurringDays,
    ridePin: ride.ridePin,
    status: ride.status,
    version: ride.version,
    createdAt: ride.createdAt,
    updatedAt: ride.updatedAt,
  };
}

export function toBooking(booking: Booking) {
  return {
    id: booking.id,
    rideId: booking.rideId,
    passengerId: booking.passengerId,
    seats: booking.seats,
    status: booking.status,
    requestedAt: booking.requestedAt,
    acceptedAt: booking.acceptedAt,
    rejectedAt: booking.rejectedAt,
    cancelledAt: booking.cancelledAt,
    checkedInAt: booking.checkedInAt,
    noShowAt: booking.noShowAt,
    completedAt: booking.completedAt,
    createdAt: booking.createdAt,
  };
}