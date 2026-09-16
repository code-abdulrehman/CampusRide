import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../src/app.js';

export const app = createApp();

export interface Session {
  userId: string;
  email: string;
  accessToken: string;
  refreshToken: string;
}

export async function apiLogin(email: string, password = 'CampusRide@123'): Promise<Session> {
  const res = await request(app).post('/api/v1/auth/login').send({ email, password });
  if (res.status !== 200) {
    throw new Error(`login failed for ${email}: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return {
    userId: res.body.data.user.id,
    email,
    accessToken: res.body.data.tokens.accessToken,
    refreshToken: res.body.data.tokens.refreshToken,
  };
}

export async function registerStudent(): Promise<Session> {
  const email = `student-${randomUUID()}@campusride.test`;
  const res = await request(app).post('/api/v1/auth/register').send({
    email,
    fullName: `Test Student ${randomUUID().slice(0, 8)}`,
    password: 'CampusRide@123',
    studentId: `S-${randomUUID().slice(0, 8)}`,
  });
  if (res.status !== 201) {
    throw new Error(`register failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return {
    userId: res.body.data.user.id,
    email,
    accessToken: res.body.data.tokens.accessToken,
    refreshToken: res.body.data.tokens.refreshToken,
  };
}

export function auth(token: string) {
  return { Authorization: `Bearer ${token}` };
}

export async function fetchCampuses(): Promise<{ id: string; name: string }[]> {
  const res = await request(app).get('/api/v1/campuses');
  if (res.status !== 200) throw new Error('could not fetch campuses');
  return res.body.data.map((c: { id: string; name: string }) => ({ id: c.id, name: c.name }));
}

export async function fetchDriverVehicle(driverToken: string, ownerId: string) {
  const res = await request(app).get('/api/v1/vehicles/me').set(auth(driverToken));
  if (res.status !== 200) throw new Error('could not fetch vehicles');
  const vehicle = res.body.data.find(
    (v: { ownerId: string; verificationStatus: string; active: boolean }) =>
      v.ownerId === ownerId && v.verificationStatus === 'VERIFIED' && v.active,
  );
  if (!vehicle) throw new Error('no verified active vehicle for driver');
  return vehicle;
}

export function tomorrowDate(): string {
  const d = new Date(Date.now() + 86_400_000);
  return d.toISOString().slice(0, 10);
}