import { rateLimit } from 'express-rate-limit';
import { fail } from '../common/response/response.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { env } from '../config/env.js';

export const apiRateLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  limit: env.RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => env.NODE_ENV === 'test',
  message: () => fail(ErrorCodes.RATE_LIMITED, 'Too many requests, please try again later'),
});