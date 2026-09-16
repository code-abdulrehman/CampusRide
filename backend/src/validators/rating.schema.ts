import { z } from 'zod';

export const createRatingSchema = z
  .object({
    overall: z.number().int().min(1).max(5),
    punctuality: z.number().int().min(1).max(5),
    behaviour: z.number().int().min(1).max(5),
    communication: z.number().int().min(1).max(5),
    comment: z.string().max(500).optional(),
  })
  .strict();