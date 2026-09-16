import pino from 'pino';
import { env } from './env.js';

const transport =
  env.NODE_ENV !== 'production'
    ? ({
        target: 'pino-pretty',
        options: { colorize: true, translateTime: 'SYS:HH:MM:ss.l' },
      } as const)
    : undefined;

export const logger = pino({
  level: env.LOG_LEVEL,
  transport,
});