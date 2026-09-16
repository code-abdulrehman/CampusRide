import { randomUUID } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { apiLogin, app, auth, registerStudent } from './helpers.js';

describe('auth', () => {
  it('registers a student with auto-verification and returns tokens', async () => {
    const session = await registerStudent();
    expect(session.accessToken).toBeTruthy();
    expect(session.refreshToken).toBeTruthy();
    const me = await request(app).get('/api/v1/users/me').set(auth(session.accessToken));
    expect(me.status).toBe(200);
    expect(me.body.data.studentVerified).toBe('VERIFIED');
    expect(me.body.data.driverVerified).toBe('PENDING');
  });

  it('rejects duplicate email registration', async () => {
    const email = `dup-${randomUUID()}@campusride.test`;
    const payload = {
      email,
      fullName: 'Dup Student',
      password: 'CampusRide@123',
      studentId: `S-${randomUUID().slice(0, 8)}`,
    };
    const first = await request(app).post('/api/v1/auth/register').send(payload);
    expect(first.status).toBe(201);
    const dup = await request(app).post('/api/v1/auth/register').send(payload);
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('EMAIL_TAKEN');
  });

  it('fails login with wrong password', async () => {
    const session = await registerStudent();
    const res = await request(app).post('/api/v1/auth/login').send({
      email: session.email,
      password: 'wrong-pass-1',
    });
    expect(res.status).toBe(401);
  });

  it('rotates the refresh token and revokes the old one', async () => {
    const session = await registerStudent();
    const first = await request(app).post('/api/v1/auth/refresh').send({
      refreshToken: session.refreshToken,
    });
    expect(first.status).toBe(200);
    const second = await request(app).post('/api/v1/auth/refresh').send({
      refreshToken: session.refreshToken,
    });
    expect(second.status).toBe(401);
    expect(second.body.error.code).toBe('AUTH_REFRESH_REVOKED');

    const third = await request(app).post('/api/v1/auth/refresh').send({
      refreshToken: first.body.data.tokens.refreshToken,
    });
    expect(third.status).toBe(200);
  });

  it('revokes refresh tokens on logout', async () => {
    const session = await registerStudent();
    const out = await request(app).post('/api/v1/auth/logout').send({
      refreshToken: session.refreshToken,
    });
    expect(out.status).toBe(200);
    const refresh = await request(app).post('/api/v1/auth/refresh').send({
      refreshToken: session.refreshToken,
    });
    expect(refresh.status).toBe(401);
  });

  it('logs in seeded users', async () => {
    const admin = await apiLogin('admin@campusride.test');
    const driver = await apiLogin('driver1@campusride.test');
    expect(admin.userId).toBeTruthy();
    expect(driver.userId).toBeTruthy();
  });
});