import { z } from 'zod';

export const vehicleTypeSchema = z.enum(['SEDAN', 'HATCHBACK', 'SUV', 'VAN', 'MOTORBIKE', 'OTHER']);

export const createVehicleSchema = z
  .object({
    vehicleType: vehicleTypeSchema,
    company: z.string().min(1).max(80),
    model: z.string().min(1).max(80),
    year: z.number().int().min(1990).max(2100),
    color: z.string().min(1).max(40),
    registrationNumber: z.string().min(3).max(20),
    totalSeats: z.number().int().min(2).max(20),
    passengerCapacity: z.number().int().min(1).max(20),
  })
  .strict();

export const updateVehicleSchema = createVehicleSchema.partial().strict();