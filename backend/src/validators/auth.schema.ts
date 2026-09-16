import { z } from 'zod';
import { PASSWORD_REGEX } from '../config/constants.js';

export const registerSchema = z
  .object({
    email: z.string().email().max(254),
    fullName: z.string().min(2).max(120),
    password: z.string().min(8).max(128).regex(PASSWORD_REGEX, 'Password needs letters, a number and a symbol'),
    studentId: z.string().min(1).max(60).optional(),
    mainCampusId: z.string().uuid().optional(),
  })
  .strict();

export const loginSchema = z
  .object({
    email: z.string().email(),
    password: z.string().min(1).max(128),
  })
  .strict();

export const refreshSchema = z
  .object({
    refreshToken: z.string().min(20).max(256),
  })
  .strict();

export const logoutSchema = refreshSchema;