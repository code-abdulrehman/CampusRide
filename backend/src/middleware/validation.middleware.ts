import { NextFunction, Request, Response } from 'express';
import type { ZodSchema } from 'zod';
import { ApiError } from '../common/errors/api-error.js';

function parse(schema: ZodSchema, value: unknown, target: string): unknown {
  const result = schema.safeParse(value);
  if (!result.success) {
    const issues = result.error.issues.map((issue) => ({
      path: issue.path.join('.'),
      message: issue.message,
    }));
    throw new ApiError(400, 'VALIDATION_ERROR', `Invalid ${target}`, issues);
  }
  return result.data;
}

export function validateBody(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    req.body = parse(schema, req.body, 'request body');
    next();
  };
}

export function validateQuery(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const parsed = parse(schema, req.query, 'query parameters');
    Object.defineProperty(req, 'query', {
      value: parsed,
      writable: true,
      configurable: true,
      enumerable: true,
    });
    next();
  };
}

export function validateParams(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    req.params = parse(schema, req.params, 'path parameters') as Request['params'];
    next();
  };
}