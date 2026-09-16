import { z } from 'zod';

export const updateMeSchema = z
  .object({
    fullName: z.string().min(2).max(120).optional(),
    mainCampusId: z.string().uuid().nullable().optional(),
  })
  .strict();

export const setAvatarSchema = z
  .object({
    avatarKey: z.string().regex(/^avatar_\d{2}$/, 'avatarKey must be like avatar_01'),
  })
  .strict();