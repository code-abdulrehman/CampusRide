import type { ErrorRequestHandler, RequestHandler } from 'express';
import { ApiError } from '../common/errors/api-error.js';
import { fail } from '../common/response/response.js';
import { logger } from '../config/logger.js';

export const notFound: RequestHandler = (req) => {
  throw new ApiError(404, 'NOT_FOUND', `No route for ${req.method} ${req.originalUrl}`);
};

export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  const reqLogger = (req as unknown as { log?: typeof logger }).log ?? logger;

  if (err instanceof ApiError) {
    reqLogger.warn({ status: err.statusCode, code: err.code }, err.message);
    res.status(err.statusCode).json(fail(err.code, err.message, err.fields));
    return;
  }

  reqLogger.error({ err }, 'Unhandled error');
  res.status(500).json(fail('INTERNAL_ERROR', 'Internal server error'));
};