import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { prisma } from '../config/prisma.js';
import { createNotification } from './notification.service.js';

export interface CreateRatingInput {
  overall: number;
  punctuality: number;
  behaviour: number;
  communication: number;
  comment?: string;
}

export async function createRating(userId: string, rideId: string, input: CreateRatingInput) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  if (ride.status !== 'COMPLETED') {
    throw new ApiError(409, ErrorCodes.RIDE_INVALID_STATE, 'Only completed rides can be rated');
  }

  let revieweeId: string;
  if (ride.driverId === userId) {
    const passenger = await prisma.booking.findFirst({
      where: { rideId, status: 'COMPLETED' },
      select: { passengerId: true },
    });
    if (!passenger) {
      throw new ApiError(403, ErrorCodes.NOT_RIDE_PARTICIPANT, 'No passenger to rate');
    }
    revieweeId = passenger.passengerId;
  } else {
    const booking = await prisma.booking.findFirst({
      where: { rideId, passengerId: userId, status: 'COMPLETED' },
      select: { id: true },
    });
    if (!booking) {
      throw new ApiError(403, ErrorCodes.NOT_RIDE_PARTICIPANT, 'Not a participant of this ride');
    }
    revieweeId = ride.driverId;
  }

  const existing = await prisma.rating.findUnique({
    where: {
      rideId_reviewerId_revieweeId: { rideId, reviewerId: userId, revieweeId },
    },
  });
  if (existing) {
    throw new ApiError(409, ErrorCodes.ALREADY_RATED, 'You already rated on this ride');
  }

  const rating = await prisma.rating.create({
    data: {
      rideId,
      reviewerId: userId,
      revieweeId,
      overall: input.overall,
      punctuality: input.punctuality,
      behaviour: input.behaviour,
      communication: input.communication,
      comment: input.comment ?? null,
    },
  });

  const aggregate = await prisma.rating.aggregate({
    where: { revieweeId },
    _avg: { overall: true },
  });
  await prisma.user.update({
    where: { id: revieweeId },
    data: { ratingAverage: aggregate._avg.overall ?? 0 },
  });

  if (revieweeId === ride.driverId) {
    await createNotification({
      userId: revieweeId,
      type: 'GENERAL',
      title: 'New rating',
      body: 'You received a new rating for your recent ride.',
      data: { rideId },
    });
  }

  return {
    ...rating,
    reviewerId: userId,
    revieweeId,
  };
}

export async function ratingsForUser(userId: string) {
  const ratings = await prisma.rating.findMany({
    where: { revieweeId: userId },
    include: {
      reviewer: { select: { id: true, fullName: true, avatarKey: true } },
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });
  return ratings.map((r) => ({
    id: r.id,
    rideId: r.rideId,
    overall: r.overall,
    punctuality: r.punctuality,
    behaviour: r.behaviour,
    communication: r.communication,
    comment: r.comment,
    createdAt: r.createdAt,
    reviewer: r.reviewer,
  }));
}