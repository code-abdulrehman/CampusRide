import { randomUUID } from 'node:crypto';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';
import swaggerUi from 'swagger-ui-express';
import { API_PREFIX, BODY_SIZE_LIMIT } from './config/constants.js';
import { env } from './config/env.js';
import { logger } from './config/logger.js';
import { loadOpenApiSpec } from './docs/openapi.js';
import { errorHandler, notFound } from './middleware/error.middleware.js';
import { apiRateLimiter } from './middleware/rate-limit.middleware.js';
import { apiRouter } from './routes/index.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');

  app.use(
    pinoHttp({
      logger,
      genReqId: (req, res) => {
        const id = (req.headers['x-request-id'] as string | undefined) ?? randomUUID();
        res.setHeader('x-request-id', id);
        return id;
      },
      redact: {
        paths: ['req.headers.authorization', 'req.headers.cookie'],
        censor: '[REDACTED]',
      },
    }),
  );

  app.use(helmet());

  const corsOrigins =
    env.CORS_ORIGINS === '*' ? true : env.CORS_ORIGINS.split(',').map((o) => o.trim());
  app.use(cors({ origin: corsOrigins }));

  app.use(express.json({ limit: BODY_SIZE_LIMIT }));

  app.use(API_PREFIX, apiRateLimiter, apiRouter);

  app.use('/docs', swaggerUi.serve, swaggerUi.setup(loadOpenApiSpec()));

  app.use(notFound);
  app.use(errorHandler);

  return app;
}