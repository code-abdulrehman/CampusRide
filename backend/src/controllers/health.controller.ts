import type { RequestHandler } from 'express';
import { ok, fail } from '../common/response/response.js';
import { prisma } from '../config/prisma.js';

export const health: RequestHandler = (_req, res) => {
  res.json(
    ok({
      status: 'ok',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    }),
  );
};

export const ready: RequestHandler = async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json(ok({ status: 'ready' }));
  } catch {
    res.status(503).json(fail('SERVICE_UNAVAILABLE', 'Database connection failed'));
  }
};