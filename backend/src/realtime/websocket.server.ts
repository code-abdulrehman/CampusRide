import type { Server } from 'node:http';
import { WebSocket, WebSocketServer } from 'ws';
import { prisma } from '../config/prisma.js';
import { verifyAccessToken } from '../services/token.service.js';
import { buildEvent, EventTypes, rideChannel, routeChannel, userChannel } from './events.js';
import { hub, type RealtimeHub } from './realtime-publisher.js';
import { handleLocationUpdate } from './location.handler.js';

const MAX_PAYLOAD = 16 * 1024;
const HEARTBEAT_MS = 30_000;

interface WsClient {
  isAlive: boolean;
}

const sockets = new WeakMap<WebSocket, WsClient>();

export function attachWebSocket(server: Server): void {
  const wss = new WebSocketServer({ server, path: '/ws', maxPayload: MAX_PAYLOAD });

  wss.on('connection', (socket: WebSocket) => {
    hub.addConnection(socket);
    sockets.set(socket, { isAlive: true });

    socket.on('pong', () => {
      const entry = sockets.get(socket);
      if (entry) entry.isAlive = true;
    });

    socket.on('message', (raw) => {
      void handleMessage(hub, socket, raw.toString());
    });

    socket.on('close', () => {
      hub.disconnect(socket);
      sockets.delete(socket);
    });
    socket.on('error', () => {
      socket.terminate();
    });
  });

  const interval = setInterval(() => {
    wss.clients.forEach((socket) => {
      const entry = sockets.get(socket);
      if (!entry) return;
      if (!entry.isAlive) {
        hub.disconnect(socket);
        socket.terminate();
        return;
      }
      entry.isAlive = false;
      socket.ping();
    });
  }, HEARTBEAT_MS);

  wss.on('close', () => clearInterval(interval));
}

function sendError(socket: WebSocket, message: string): void {
  socket.send(JSON.stringify(buildEvent('ws.error', { message, resyncRequired: true })));
}

async function handleMessage(hub: RealtimeHub, socket: WebSocket, raw: string): Promise<void> {
  let msg: { type?: string; data?: unknown };
  try {
    msg = JSON.parse(raw);
  } catch {
    sendError(socket, 'Invalid JSON message');
    return;
  }

  switch (msg.type) {
    case 'auth': {
      const token = (msg.data as { token?: string } | undefined)?.token;
      if (!token) {
        sendError(socket, 'auth requires a token');
        return;
      }
      try {
        const payload = verifyAccessToken(token);
        hub.authenticate(socket, payload.sub);
        hub.subscribe(socket, userChannel(payload.sub));
        socket.send(
          JSON.stringify(
            buildEvent(EventTypes.SystemConnected, {
              userId: payload.sub,
              channels: [userChannel(payload.sub)],
            }),
          ),
        );
      } catch {
        sendError(socket, 'Invalid access token');
      }
      return;
    }

    case 'subscribe.route': {
      if (!hub.isAuthenticated(socket)) {
        sendError(socket, 'Authenticate first');
        return;
      }
      const d = msg.data as { fromCampusId?: string; toCampusId?: string; date?: string };
      if (!d?.fromCampusId || !d.toCampusId || !d.date) {
        sendError(socket, 'subscribe.route requires fromCampusId, toCampusId, date');
        return;
      }
      hub.subscribe(socket, routeChannel(d.fromCampusId, d.toCampusId, d.date));
      return;
    }

    case 'unsubscribe.route': {
      const d = msg.data as { fromCampusId?: string; toCampusId?: string; date?: string };
      if (d?.fromCampusId && d.toCampusId && d.date) {
        hub.unsubscribe(socket, routeChannel(d.fromCampusId, d.toCampusId, d.date));
      }
      return;
    }

    case 'subscribe.ride': {
      const userId = hub.getUserId(socket);
      if (!userId) {
        sendError(socket, 'Authenticate first');
        return;
      }
      const rideId = (msg.data as { rideId?: string } | undefined)?.rideId;
      if (!rideId) {
        sendError(socket, 'subscribe.ride requires rideId');
        return;
      }
      const authorized = await isRideParticipant(userId, rideId);
      if (!authorized) {
        sendError(socket, 'Not a ride participant');
        return;
      }
      hub.subscribe(socket, rideChannel(rideId));
      return;
    }

    case 'unsubscribe.ride': {
      const rideId = (msg.data as { rideId?: string } | undefined)?.rideId;
      if (rideId) hub.unsubscribe(socket, rideChannel(rideId));
      return;
    }

    case 'location.update': {
      const userId = hub.getUserId(socket);
      if (!userId) {
        sendError(socket, 'Authenticate first');
        return;
      }
      try {
        await handleLocationUpdate(hub, userId, msg.data);
      } catch (err) {
        sendError(socket, err instanceof Error ? err.message : 'Location update failed');
      }
      return;
    }

    case 'ping': {
      socket.send(JSON.stringify(buildEvent('system.pong', {})));
      return;
    }

    default: {
      sendError(socket, `Unsupported message type: ${String(msg.type)}`);
    }
  }
}

async function isRideParticipant(userId: string, rideId: string): Promise<boolean> {
  const ride = await prisma.ride.findUnique({
    where: { id: rideId },
    select: { driverId: true },
  });
  if (!ride) return false;
  if (ride.driverId === userId) return true;
  const booking = await prisma.booking.findFirst({
    where: {
      rideId,
      passengerId: userId,
      status: {
        in: ['REQUESTED', 'ACCEPTED', 'CHECKED_IN', 'RIDE_STARTED', 'COMPLETED', 'NO_SHOW'],
      },
    },
    select: { id: true },
  });
  return booking != null;
}