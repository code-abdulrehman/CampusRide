import { RideRequestStatus } from '@prisma/client';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { prisma } from '../config/prisma.js';
import { scoreRide } from './matching.service.js';
import { buildEvent, channelDate, EventTypes, routeChannel } from '../realtime/events.js';
import { hub } from '../realtime/realtime-publisher.js';

export interface CreateRideRequestInput {
  originCampusId: string;
  destinationCampusId: string;
  earliestDeparture: Date;
  latestDeparture: Date;
  requiredArrival?: Date;
  requiredSeats?: number;
  maxBudget?: number;
  maxPickupDistanceKm?: number;
}

function serializeRequest(r: {
  id: string;
  studentId: string;
  originCampusId: string;
  destinationCampusId: string;
  earliestDeparture: Date;
  latestDeparture: Date;
  requiredArrival: Date | null;
  requiredSeats: number;
  maxBudget: number | null;
  maxPickupDistanceKm: number;
  status: RideRequestStatus;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: r.id,
    studentId: r.studentId,
    originCampusId: r.originCampusId,
    destinationCampusId: r.destinationCampusId,
    earliestDeparture: r.earliestDeparture,
    latestDeparture: r.latestDeparture,
    requiredArrival: r.requiredArrival,
    requiredSeats: r.requiredSeats,
    maxBudget: r.maxBudget,
    maxPickupDistanceKm: r.maxPickupDistanceKm,
    status: r.status,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  };
}

export async function createRideRequest(userId: string, input: CreateRideRequestInput) {
  if (input.originCampusId === input.destinationCampusId) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'Origin and destination campuses must differ');
  }
  if (input.earliestDeparture.getTime() >= input.latestDeparture.getTime()) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'Latest departure must be after earliest departure');
  }
  const campuses = await prisma.campus.findMany({
    where: { id: { in: [input.originCampusId, input.destinationCampusId] }, active: true },
    select: { id: true },
  });
  if (campuses.length !== 2) {
    throw new ApiError(400, ErrorCodes.CAMPUS_NOT_FOUND, 'Campus not found');
  }

  const request = await prisma.rideRequest.create({
    data: {
      studentId: userId,
      originCampusId: input.originCampusId,
      destinationCampusId: input.destinationCampusId,
      earliestDeparture: input.earliestDeparture,
      latestDeparture: input.latestDeparture,
      requiredArrival: input.requiredArrival ?? null,
      requiredSeats: input.requiredSeats ?? 1,
      maxBudget: input.maxBudget ?? null,
      maxPickupDistanceKm: input.maxPickupDistanceKm ?? 3,
      status: RideRequestStatus.OPEN,
    },
  });

  hub.publish(
    routeChannel(input.originCampusId, input.destinationCampusId, channelDate(input.earliestDeparture)),
    buildEvent(EventTypes.RideRequestCreated, { rideRequest: serializeRequest(request) }),
  );

  return serializeRequest(request);
}

export async function myRideRequests(userId: string) {
  const requests = await prisma.rideRequest.findMany({
    where: { studentId: userId },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });
  return requests.map(serializeRequest);
}

export async function getRideRequest(userId: string, requestId: string) {
  const request = await prisma.rideRequest.findFirst({
    where: { id: requestId, studentId: userId },
  });
  if (!request) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'Ride request not found');
  return serializeRequest(request);
}

export async function updateRideRequest(userId: string, requestId: string, input: Partial<CreateRideRequestInput>) {
  const request = await prisma.rideRequest.findFirst({
    where: { id: requestId, studentId: userId },
  });
  if (!request) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'Ride request not found');
  if (request.status !== 'OPEN') {
    throw new ApiError(409, ErrorCodes.BOOKING_INVALID_STATE, 'Only open requests can be edited');
  }

  const data: Record<string, unknown> = {};
  if (input.earliestDeparture !== undefined) data.earliestDeparture = input.earliestDeparture;
  if (input.latestDeparture !== undefined) data.latestDeparture = input.latestDeparture;
  if (input.requiredArrival !== undefined) data.requiredArrival = input.requiredArrival ?? null;
  if (input.requiredSeats !== undefined) data.requiredSeats = input.requiredSeats;
  if (input.maxBudget !== undefined) data.maxBudget = input.maxBudget ?? null;
  if (input.maxPickupDistanceKm !== undefined) data.maxPickupDistanceKm = input.maxPickupDistanceKm;

  const updated = await prisma.rideRequest.update({
    where: { id: requestId },
    data,
  });

  hub.publish(
    routeChannel(updated.originCampusId, updated.destinationCampusId, channelDate(updated.earliestDeparture)),
    buildEvent(EventTypes.RideRequestUpdated, { rideRequest: serializeRequest(updated) }),
  );

  return serializeRequest(updated);
}

export async function cancelRideRequest(userId: string, requestId: string) {
  const request = await prisma.rideRequest.findFirst({
    where: { id: requestId, studentId: userId },
  });
  if (!request) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'Ride request not found');
  if (request.status === 'CANCELLED') return serializeRequest(request);
  if (request.status !== 'OPEN') {
    throw new ApiError(409, ErrorCodes.BOOKING_INVALID_STATE, 'Only open requests can be cancelled');
  }
  const updated = await prisma.rideRequest.update({
    where: { id: requestId },
    data: { status: 'CANCELLED' },
  });
  return serializeRequest(updated);
}

export async function getRideRequestMatches(userId: string, requestId: string) {
  const request = await prisma.rideRequest.findFirst({
    where: { id: requestId, studentId: userId },
  });
  if (!request) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'Ride request not found');

  const ride = await prisma.ride.findMany({
    where: {
      originCampusId: request.originCampusId,
      destinationCampusId: request.destinationCampusId,
      status: 'OPEN',
      availableSeats: { gte: request.requiredSeats },
      departureAt: { gte: request.earliestDeparture, lte: request.latestDeparture },
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
          company: true,
          model: true,
          color: true,
          vehicleType: true,
        },
      },
    },
    orderBy: { departureAt: 'asc' },
    take: 50,
  });

  const items = ride.map((r) => ({
    ride: {
      id: r.id,
      origin: r.origin,
      destination: r.destination,
      departureAt: r.departureAt,
      expectedArrivalAt: r.expectedArrivalAt,
      availableSeats: r.availableSeats,
      pricePerSeat: r.pricePerSeat,
      status: r.status,
    },
    driver: r.driver,
    vehicle: r.vehicle,
    match: scoreRide(
      {
        originCampusId: r.originCampusId,
        destinationCampusId: r.destinationCampusId,
        departureAt: r.departureAt,
        pricePerSeat: r.pricePerSeat,
        pickupRadiusKm: r.pickupRadiusKm,
        ratingAverage: r.driver.ratingAverage,
        completedRidesCount: r.driver.completedRidesCount,
        cancellationCount: r.driver.cancellationCount,
      },
      {
        fromCampusId: request.originCampusId,
        toCampusId: request.destinationCampusId,
        seats: request.requiredSeats,
        startTime: request.earliestDeparture.toISOString().slice(11, 16),
        endTime: request.latestDeparture.toISOString().slice(11, 16),
        maxBudget: request.maxBudget ?? undefined,
      },
    ),
  })).sort((a, b) => b.match.matchScore - a.match.matchScore);

  return { items, total: items.length };
}