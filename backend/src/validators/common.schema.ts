import { z } from 'zod';

export const uuidParam = z.string().uuid();

export const idParamSchema = z.object({ id: z.string().uuid() });
export const rideIdParamSchema = z.object({ rideId: z.string().uuid() });
export const reportingIdParamSchema = z.object({
  id: z.string().uuid(),
}) as z.ZodType<{ id: string }>;
export const userIdParamSchema = z.object({ userId: z.string().uuid() });
export const vehicleIdParamSchema = z.object({ vehicleId: z.string().uuid() });

export const paginationQuerySchema = z
  .object({
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
  })
  .strict();

export const isoDateTime = z.string().datetime({ offset: true }).transform((s) => new Date(s));
export const optionalIsoDateTime = z
  .string()
  .datetime({ offset: true })
  .optional()
  .transform((s) => (s === undefined ? undefined : new Date(s)) as Date | undefined);

export const hourMinute = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);

export const uuidOrEmpty = z.union([z.string().uuid(), z.literal('')]).transform((v) => (v === '' ? undefined : v));