import { z } from 'zod';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { prisma } from '../config/prisma.js';
import { buildEvent, EventTypes, rideChannel } from './events.js';
import type { RealtimeHub } from './realtime-publisher.js';

const locationSchema = z.object({
  rideId: z.string().uuid(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  accuracy: z.number().nonnegative().optional(),
  heading: z.number().min(0).max(360).optional(),
  speed: z.number().nonnegative().optional(),
  capturedAt: z.string().datetime().optional(),
});

const MIN_INTERVAL_MS = 3000;
const lastUpdates = new Map<string, number>();

export async function handleLocationUpdate(
  hub: RealtimeHub,
  userId: string,
  payload: unknown,
): Promise<void> {
  const data = locationSchema.parse(payload);

  const key = `${data.rideId}:${userId}`;
  const last = lastUpdates.get(key);
  const now = Date.now();
  if (last && now - last < MIN_INTERVAL_MS) {
    throw new ApiError(429, ErrorCodes.LOCATION_NOT_ALLOWED, 'Location update too frequent');
  }

  const ride = await prisma.ride.findUnique({ where: { id: data.rideId } });
  if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  if (ride.driverId !== userId) {
    throw new ApiError(403, ErrorCodes.LOCATION_NOT_ALLOWED, 'Only the ride driver may send location');
  }
  if (ride.status !== 'STARTED') {
    throw new ApiError(409, ErrorCodes.RIDE_INVALID_STATE, 'Location requires an active (started) ride');
  }

  await prisma.rideLocation.upsert({
    where: { rideId_userId: { rideId: data.rideId, userId } },
    create: {
      rideId: data.rideId,
      userId,
      latitude: data.latitude,
      longitude: data.longitude,
      accuracy: data.accuracy,
      heading: data.heading,
      speed: data.speed,
      updatedAt: new Date(),
    },
    update: {
      latitude: data.latitude,
      longitude: data.longitude,
      accuracy: data.accuracy,
      heading: data.heading,
      speed: data.speed,
    },
  });

  lastUpdates.set(key, now);

  hub.publish(
    rideChannel(data.rideId),
    buildEvent(EventTypes.LocationUpdated, {
      rideId: data.rideId,
      latitude: data.latitude,
      longitude: data.longitude,
      accuracy: data.accuracy ?? null,
      heading: data.heading ?? null,
      speed: data.speed ?? null,
      capturedAt: data.capturedAt ?? new Date().toISOString(),
    }),
  );
}