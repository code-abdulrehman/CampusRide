import type { WebSocket } from 'ws';
import type { RealtimeEvent } from './events.js';

interface Client {
  userId: string | null;
  channels: Set<string>;
}

export class RealtimeHub {
  private readonly clients = new Map<WebSocket, Client>();
  private readonly users = new Map<string, Set<WebSocket>>();
  private readonly channelClients = new Map<string, Set<WebSocket>>();

  addConnection(socket: WebSocket): void {
    this.clients.set(socket, { userId: null, channels: new Set() });
  }

  authenticate(socket: WebSocket, userId: string): boolean {
    const client = this.clients.get(socket);
    if (!client) return false;
    if (client.userId) {
      this.users.get(client.userId)?.delete(socket);
    }
    client.userId = userId;
    if (!this.users.has(userId)) this.users.set(userId, new Set());
    this.users.get(userId)!.add(socket);
    return true;
  }

  isAuthenticated(socket: WebSocket): boolean {
    return this.clients.get(socket)?.userId != null;
  }

  getUserId(socket: WebSocket): string | null {
    return this.clients.get(socket)?.userId ?? null;
  }

  subscribe(socket: WebSocket, channel: string): boolean {
    const client = this.clients.get(socket);
    if (!client || !client.userId) return false;
    if (client.channels.has(channel)) return true;
    client.channels.add(channel);
    if (!this.channelClients.has(channel)) this.channelClients.set(channel, new Set());
    this.channelClients.get(channel)!.add(socket);
    return true;
  }

  unsubscribe(socket: WebSocket, channel: string): void {
    const client = this.clients.get(socket);
    if (!client) return;
    client.channels.delete(channel);
    this.channelClients.get(channel)?.delete(socket);
  }

  clearChannels(socket: WebSocket): void {
    const client = this.clients.get(socket);
    if (!client) return;
    for (const channel of client.channels) {
      this.channelClients.get(channel)?.delete(socket);
    }
    this.channelClients.forEach((set) => set.delete(socket));
    client.channels.clear();
  }

  disconnectedSocketsForUser(userId: string): number {
    return this.users.get(userId)?.size ?? 0;
  }

  disconnect(socket: WebSocket): void {
    const client = this.clients.get(socket);
    if (!client) return;
    if (client.userId) {
      this.users.get(client.userId)?.delete(socket);
    }
    this.clearChannels(socket);
    this.clients.delete(socket);
  }

  publish(channel: string, payload: RealtimeEvent): number {
    const targets = this.channelClients.get(channel);
    if (!targets || targets.size === 0) return 0;
    const raw = JSON.stringify(payload);
    let sent = 0;
    for (const socket of targets) {
      if (socket.readyState === socket.OPEN) {
        socket.send(raw);
        sent += 1;
      }
    }
    return sent;
  }
}

export const hub = new RealtimeHub();