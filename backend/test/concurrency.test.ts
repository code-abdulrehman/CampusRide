import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { apiLogin, app, auth, fetchCampuses, fetchDriverVehicle, registerStudent, tomorrowDate } from './helpers.js';

describe('booking concurrency', () => {
  it('allows exactly one passenger to take the last seat', async () => {
    const driver = await apiLogin('driver1@campusride.test');
    const s1 = await registerStudent();
    const s2 = await registerStudent();
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
        departureAt: `${date}T10:00:00.000Z`,
        availableSeats: 1,
        pricePerSeat: 180,
      });
    const rideId = create.body.data.ride.id;

    const b1 = await request(app)
      .post(`/api/v1/rides/${rideId}/bookings`)
      .set(auth(s1.accessToken))
      .send({ seats: 1 });
    const b2 = await request(app)
      .post(`/api/v1/rides/${rideId}/bookings`)
      .set(auth(s2.accessToken))
      .send({ seats: 1 });
    expect(b1.status).toBe(201);
    expect(b2.status).toBe(201);

    const [r1, r2] = await Promise.all([
      request(app).post(`/api/v1/bookings/${b1.body.data.booking.id}/accept`).set(auth(driver.accessToken)),
      request(app).post(`/api/v1/bookings/${b2.body.data.booking.id}/accept`).set(auth(driver.accessToken)),
    ]);

    const statuses = [r1.status, r2.status].sort();
    expect(statuses).toEqual([200, 409]);
    const winner = r1.status === 200 ? r1 : r2;
    expect(winner.body.data.ride.availableSeats).toBe(0);
    expect(winner.body.data.ride.status).toBe('FULL');
  }, 30_000);
});