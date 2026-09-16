import { z } from 'zod';
import { hourMinute, isoDateTime, optionalIsoDateTime } from './common.schema.js';

export const createRideSchema = z
  .object({
    vehicleId: z.string().uuid(),
    originCampusId: z.string().uuid(),
    destinationCampusId: z.string().uuid(),
    origin: z.string().min(1).max(120),
    destination: z.string().min(1).max(120),
    departureAt: isoDateTime,
    expectedArrivalAt: optionalIsoDateTime,
    availableSeats: z.coerce.number().int().min(1).max(20).default(1),
    pricePerSeat: z.coerce.number().int().min(0).max(100000).default(200),
    pickupRadiusKm: z.coerce.number().min(0).max(50).default(2),
    maxDetourMinutes: z.coerce.number().int().min(0).max(240).default(30),
    conditions: z.array(z.string().min(1).max(80)).max(20).optional(),
    notes: z.string().max(500).optional(),
    recurring: z.boolean().optional(),
    recurringDays: z.array(z.number().int().min(0).max(6)).max(7).optional(),
  })
  .strict();

export const searchRideQuerySchema = z
  .object({
    fromCampusId: z.string().uuid(),
    toCampusId: z.string().uuid(),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    seats: z.coerce.number().int().min(1).max(20).default(1),
    startTime: hourMinute.optional(),
    endTime: hourMinute.optional(),
    maxBudget: z.coerce.number().int().min(1).max(100000).optional(),
    page: z.coerce.number().int().min(1).optional(),
    pageSize: z.coerce.number().int().min(1).max(100).optional(),
  })
  .strict();

export const updateRideSchema = z
  .object({
    departureAt: isoDateTime.optional(),
    expectedArrivalAt: optionalIsoDateTime,
    pricePerSeat: z.coerce.number().int().min(0).max(100000).optional(),
    availableSeats: z.coerce.number().int().min(1).max(20).optional(),
    pickupRadiusKm: z.coerce.number().min(0).max(50).optional(),
    maxDetourMinutes: z.coerce.number().int().min(0).max(240).optional(),
    conditions: z.array(z.string().min(1).max(80)).max(20).optional(),
    notes: z.string().max(500).nullable().optional(),
  })
  .strict();

export const createRideRequestSchema = z
  .object({
    originCampusId: z.string().uuid(),
    destinationCampusId: z.string().uuid(),
    earliestDeparture: isoDateTime,
    latestDeparture: isoDateTime,
    requiredArrival: optionalIsoDateTime,
    requiredSeats: z.coerce.number().int().min(1).max(20).default(1),
    maxBudget: z.coerce.number().int().min(1).max(100000).optional(),
    maxPickupDistanceKm: z.coerce.number().min(0).max(50).default(3),
  })
  .strict();

export const updateRideRequestSchema = createRideRequestSchema.partial().strict();