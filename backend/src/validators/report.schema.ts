import { z } from 'zod';

const reportReasonSchema = z.enum([
  'DANGEROUS_DRIVING',
  'HARASSMENT',
  'FAKE_DETAILS',
  'NO_SHOW',
  'EXCESSIVE_CHARGING',
  'MISBEHAVIOR',
  'WRONG_PICKUP',
  'SPAM',
  'OTHER',
]);

export const createReportSchema = z
  .object({
    reportedUserId: z.string().uuid().optional(),
    rideId: z.string().uuid().optional(),
    reason: reportReasonSchema,
    details: z.string().min(5).max(2000),
  })
  .strict();