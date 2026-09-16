import { z } from 'zod';

export const setUserStatusSchema = z
  .object({
    accountStatus: z.enum(['ACTIVE', 'SUSPENDED']),
  })
  .strict();

export const verifyUserSchema = z
  .object({
    status: z.enum(['VERIFIED', 'REJECTED', 'PENDING']),
  })
  .strict();

export const resolveReportSchema = z
  .object({
    status: z.enum(['RESOLVED', 'DISMISSED']).optional(),
    adminAction: z.string().max(500).optional(),
  })
  .strict();