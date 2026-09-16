import { createApp } from './app.js';
import { env } from './config/env.js';
import { logger } from './config/logger.js';
import { prisma } from './config/prisma.js';
import { attachWebSocket } from './realtime/websocket.server.js';

const app = createApp();

const server = app.listen(env.PORT, env.HOST, () => {
  logger.info({ url: `http://${env.HOST}:${env.PORT}` }, 'CampusRide backend listening');
});

attachWebSocket(server);

async function shutdown(signal: string): Promise<void> {
  logger.info({ signal }, 'Shutting down');
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));