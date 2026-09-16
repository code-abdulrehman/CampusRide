import type { Server } from 'node:http';
import { describe, expect, it } from 'vitest';
import request from 'supertest';
import WebSocket from 'ws';
import { createApp } from '../src/app.js';
import { attachWebSocket } from '../src/realtime/websocket.server.js';
import {
  apiLogin,
  app,
  auth,
  fetchCampuses,
  fetchDriverVehicle,
  registerStudent,
  tomorrowDate,
} from './helpers.js';

function openSocket(port: number): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws`);
    ws.once('open', () => resolve(ws));
    ws.once('error', reject);
  });
}

function send(ws: WebSocket, type: string, data: unknown) {
  ws.send(JSON.stringify({ type, data }));
}

function nextEvent(ws: WebSocket, timeoutMs = 5000): Promise<{ type: string; data: unknown }> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.off('message', onMessage);
      reject(new Error('timed out waiting for ws event'));
    }, timeoutMs);
    const onMessage = (raw: WebSocket.RawData) => {
      const msg = JSON.parse(raw.toString());
      clearTimeout(timer);
      ws.off('message', onMessage);
      resolve(msg);
    };
    ws.on('message', onMessage);
  });
}

async function waitForAuth(ws: WebSocket): Promise<void> {
  const timer = setTimeout(() => {
    throw new Error('timed out waiting for auth ack');
  }, 5000);
  try {
    while (true) {
      const msg = await new Promise<{ type: string }>((resolve) => {
        ws.once('message', (raw) => resolve(JSON.parse(raw.toString())));
      });
      if (msg.type === 'system.connected') break;
    }
  } finally {
    clearTimeout(timer);
  }
}

function waitForEvent(
  ws: WebSocket,
  type: string,
  timeoutMs = 5000,
): Promise<{ type: string; data: unknown }> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.off('message', onMessage);
      reject(new Error(`timed out waiting for ws event ${type}`));
    }, timeoutMs);
    const onMessage = (raw: WebSocket.RawData) => {
      const msg = JSON.parse(raw.toString());
      if (msg.type !== type) return;
      clearTimeout(timer);
      ws.off('message', onMessage);
      resolve(msg);
    };
    ws.on('message', onMessage);
  });
}

describe('realtime', () => {
  let server: Server;
  let port: number;

  it('streams booking, ride and location events to subscribers', async () => {
    const realApp = createApp();
    server = realApp.listen(0);
    port = (server.address() as { port: number }).port;
    attachWebSocket(server);

    const driver = await apiLogin('driver1@campusride.test');
    const student = await registerStudent();
    const outsider = await registerStudent();
    const campuses = await fetchCampuses();
    const vehicle = await fetchDriverVehicle(driver.accessToken, driver.userId);
    const date = tomorrowDate();

    const create = await request(app)
      .post('/api/v1/rides')
      .set(auth(driver.accessToken))
      .send({
        vehicleId: vehicle.id,
        originCampusId: campuses[0].id,
        destinationCampusId: campuses[1].id,
        origin: campuses[0].name,
        destination: campuses[1].name,
        departureAt: `${date}T11:00:00.000Z`,
        availableSeats: 1,
        pricePerSeat: 220,
      });
    const rideId = create.body.data.ride.id;

    const book = await request(app)
      .post(`/api/v1/rides/${rideId}/bookings`)
      .set(auth(student.accessToken))
      .send({ seats: 1 });
    const bookingId = book.body.data.booking.id;

    const wsDriver = await openSocket(port);
    const wsStudent = await openSocket(port);
    const wsOutsider = await openSocket(port);

    send(wsDriver, 'auth', { token: driver.accessToken });
    send(wsStudent, 'auth', { token: student.accessToken });
    send(wsOutsider, 'auth', { token: outsider.accessToken });

    await waitForAuth(wsDriver);
    await waitForAuth(wsStudent);
    await waitForAuth(wsOutsider);

    send(wsDriver, 'subscribe.ride', { rideId });
    send(wsStudent, 'subscribe.ride', { rideId });
    send(wsOutsider, 'subscribe.ride', { rideId });

    const errMsg = await nextEvent(wsOutsider);
    expect(errMsg.type).toBe('ws.error');
    expect((errMsg.data as { message: string }).message).toContain('Not a ride participant');

    const acceptedPromise = waitForEvent(wsStudent, 'booking.accepted');
    await request(app).post(`/api/v1/bookings/${bookingId}/accept`).set(auth(driver.accessToken));
    const accepted = await acceptedPromise;
    expect(accepted.type).toBe('booking.accepted');

    const startedPromise = waitForEvent(wsStudent, 'ride.started');
    await request(app).post(`/api/v1/rides/${rideId}/start`).set(auth(driver.accessToken));
    const started = await startedPromise;
    expect(started.type).toBe('ride.started');

    const locationPromise = waitForEvent(wsStudent, 'location.updated');
    send(wsDriver, 'location.update', {
      rideId,
      latitude: 31.49,
      longitude: 74.29,
      accuracy: 5,
    });
    const located = await locationPromise;
    expect(located.type).toBe('location.updated');
    expect((located.data as { latitude: number }).latitude).toBe(31.49);

    wsDriver.close();
    wsStudent.close();
    wsOutsider.close();
    server.close();
  }, 30_000);
});