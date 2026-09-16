import { z } from 'zod';

export const createBookingSchema = z
  .object({
    seats: z.coerce.number().int().min(1).max(20).default(1),
  })
  .strict();

export const checkinSchema = z
  .object({
    checkinPin: z.string().regex(/^\d{4}$/),
  })
  .strict();