import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { Role } from '@prisma/client';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { prisma } from '../config/prisma.js';
import { verifyAccessToken } from '../services/token.service.js';

export const requireAuth: RequestHandler = async (req, _res, next) => {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new ApiError(401, ErrorCodes.UNAUTHORIZED, 'Missing bearer token');
    }
    const token = header.slice('Bearer '.length).trim();
    let payload: { sub: string; role: Role };
    try {
      payload = verifyAccessToken(token);
    } catch {
      throw new ApiError(401, ErrorCodes.AUTH_TOKEN_EXPIRED, 'Invalid or expired access token');
    }
    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user) {
      throw new ApiError(401, ErrorCodes.UNAUTHORIZED, 'User no longer exists');
    }
    if (user.accountStatus === 'SUSPENDED') {
      throw new ApiError(403, ErrorCodes.ACCOUNT_SUSPENDED, 'Account is suspended');
    }
    req.user = { userId: user.id, role: user.role };
    next();
  } catch (err) {
    next(err);
  }
};

export function requireRole(...roles: Role[]): RequestHandler {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      next(new ApiError(403, ErrorCodes.FORBIDDEN, 'Insufficient permissions'));
      return;
    }
    next();
  };
}