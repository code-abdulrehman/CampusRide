import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { apiLogin, app, auth, registerStudent } from './helpers.js';

describe('admin', () => {
  it('serves a dashboard summary', async () => {
    const admin = await apiLogin('admin@campusride.test');
    const res = await request(app).get('/api/v1/admin/dashboard').set(auth(admin.accessToken));
    expect(res.status).toBe(200);
    expect(typeof res.body.data.totalUsers).toBe('number');
    expect(typeof res.body.data.totalRides).toBe('number');
  });

  it('rejects non-admin access', async () => {
    const student = await registerStudent();
    const res = await request(app).get('/api/v1/admin/dashboard').set(auth(student.accessToken));
    expect(res.status).toBe(403);
  });

  it('verifies a pending driver', async () => {
    const admin = await apiLogin('admin@campusride.test');
    const pending = await request(app)
      .get('/api/v1/admin/drivers/pending')
      .set(auth(admin.accessToken));
    expect(pending.status).toBe(200);
    const target = pending.body.data.find(
      (u: { email: string }) => u.email === 'driverpending@campusride.test',
    );
    if (!target) return;

    const verify = await request(app)
      .patch(`/api/v1/admin/drivers/${target.id}/verification`)
      .set(auth(admin.accessToken))
      .send({ status: 'VERIFIED' });
    expect(verify.status).toBe(200);
    expect(verify.body.data.driverVerified).toBe('VERIFIED');
  });

  it('suspends a user and blocks their access', async () => {
    const admin = await apiLogin('admin@campusride.test');
    const student = await registerStudent();

    const suspend = await request(app)
      .patch(`/api/v1/admin/users/${student.userId}/status`)
      .set(auth(admin.accessToken))
      .send({ accountStatus: 'SUSPENDED' });
    expect(suspend.status).toBe(200);

    const blocked = await request(app).get('/api/v1/users/me').set(auth(student.accessToken));
    expect(blocked.status).toBe(403);
    expect(blocked.body.error.code).toBe('ACCOUNT_SUSPENDED');

    const relogin = await request(app).post('/api/v1/auth/login').send({
      email: student.email,
      password: 'CampusRide@123',
    });
    expect(relogin.status).toBe(403);
    expect(relogin.body.error.code).toBe('ACCOUNT_SUSPENDED');
  });

  it('resolves a user report', async () => {
    const admin = await apiLogin('admin@campusride.test');
    const s1 = await registerStudent();
    const s2 = await registerStudent();

    const report = await request(app)
      .post('/api/v1/reports')
      .set(auth(s1.accessToken))
      .send({ reportedUserId: s2.userId, reason: 'NO_SHOW', details: 'did not show up' });
    expect(report.status).toBe(201);

    const list = await request(app)
      .get('/api/v1/admin/reports')
      .set(auth(admin.accessToken));
    const found = list.body.data.items.find((r: { id: string }) => r.id === report.body.data.id);
    expect(found).toBeTruthy();
    expect(found.status).toBe('OPEN');

    const resolve = await request(app)
      .patch(`/api/v1/admin/reports/${report.body.data.id}`)
      .set(auth(admin.accessToken))
      .send({ status: 'RESOLVED', adminAction: 'Warned the user' });
    expect(resolve.status).toBe(200);
    expect(resolve.body.data.status).toBe('RESOLVED');
  });
});