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

// Ngrok tunnel for mobile dev
if (env.NGROK_ENABLED === 'true' && env.NODE_ENV === 'development') {
  import('@ngrok/ngrok')
    .then(async (mod) => {
      const listener = await mod.default.forward({
        addr: env.PORT,
        authtoken_from_env: true,
        domain: env.NGROK_SUBDOMAIN ? `${env.NGROK_SUBDOMAIN}.ngrok-free.app` : undefined,
      });
      const url = listener.url();
      logger.info({ ngrokUrl: url }, 'Ngrok tunnel established');
      console.log('');
      console.log('╔══════════════════════════════════════════════════════════════╗');
      console.log('║                    NGROK TUNNEL ACTIVE                      ║');
      console.log(`║  ${url?.padEnd(58)}║`);
      console.log('║  Mobile app base URL:                                       ║');
      console.log(`║  ${url ? '$url/api/v1'.padEnd(58) : 'N/A'.padEnd(58)}║`);
      console.log('╚══════════════════════════════════════════════════════════════╝');
      console.log('');
    })
    .catch((err) => {
      logger.error({ err }, 'Failed to start ngrok tunnel');
      console.error('Ngrok error:', err.message);
      console.error('Set NGROK_AUTH_TOKEN in your environment or ~/.ngrok2/ngrok.yml');
    });
}

async function shutdown(signal: string): Promise<void> {
  logger.info({ signal }, 'Shutting down');
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));