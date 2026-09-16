import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { prisma } from '../src/config/prisma.js';
import { apiLogin, app, auth, fetchCampuses, fetchDriverVehicle, registerStudent, tomorrowDate } from './helpers.js';

describe('ride lifecycle', () => {
  it('creates a ride, books it, checks in, starts and completes', async () => {
    const driver = await apiLogin('driver1@campusride.test');
    const student1 = await registerStudent();
    const student2 = await registerStudent();

    const campuses = await fetchCampuses();
    const from = campuses[0];
    const to = campuses[1];
    const vehicle = await fetchDriverVehicle(driver.accessToken, driver.userId);

    const date = tomorrowDate();
    const createRes = await request(app)
      .post('/api/v1/rides')
      .set(auth(driver.accessToken))
      .send({
        vehicleId: vehicle.id,
        originCampusId: from.id,
        destinationCampusId: to.id,
        origin: from.name,
        destination: to.name,
        departureAt: `${date}T08:30:00.000Z`,
        availableSeats: 2,
        pricePerSeat: 200,
        pickupRadiusKm: 2,
        maxDetourMinutes: 30,
      });
    expect(createRes.status).toBe(201);
    const rideId = createRes.body.data.ride.id;
    expect(createRes.body.data.ride.ridePin).toBeTruthy();

    const search = await request(app)
      .get('/api/v1/rides/search')
      .query({ fromCampusId: from.id, toCampusId: to.id, date, seats: 1, pageSize: 100 })
      .set(auth(student1.accessToken));
    expect(search.status).toBe(200);
    const found = search.body.data.items.find(
      (r: { ride: { id: string } }) => r.ride.id === rideId,
    );
    expect(found).toBeTruthy();
    expect(typeof found.match.matchScore).toBe('number');

    const book1 = await request(app)
      .post(`/api/v1/rides/${rideId}/bookings`)
      .set(auth(student1.accessToken))
      .send({ seats: 1 });
    expect(book1.status).toBe(201);
    const booking1Id = book1.body.data.booking.id;

    const book2 = await request(app)
      .post(`/api/v1/rides/${rideId}/bookings`)
      .set(auth(student2.accessToken))
      .send({ seats: 1 });
    expect(book2.status).toBe(201);
    const booking2Id = book2.body.data.booking.id;

    const accept1 = await request(app)
      .post(`/api/v1/bookings/${booking1Id}/accept`)
      .set(auth(driver.accessToken));
    expect(accept1.status).toBe(200);
    expect(accept1.body.data.booking.status).toBe('ACCEPTED');
    expect(accept1.body.data.ride.availableSeats).toBe(1);

    const accept2 = await request(app)
      .post(`/api/v1/bookings/${booking2Id}/accept`)
      .set(auth(driver.accessToken));
    expect(accept2.status).toBe(200);
    expect(accept2.body.data.booking.status).toBe('ACCEPTED');
    expect(accept2.body.data.ride.availableSeats).toBe(0);
    expect(accept2.body.data.ride.status).toBe('FULL');

    const ridePin = (await prisma.ride.findUnique({ where: { id: rideId } }))!.ridePin;

    const studentCannotCheckin = await request(app)
      .post(`/api/v1/bookings/${booking2Id}/checkin`)
      .set(auth(student2.accessToken))
      .send({ checkinPin: ridePin });
    expect(studentCannotCheckin.status).toBe(403);

    const wrongPin = await request(app)
      .post(`/api/v1/bookings/${booking2Id}/checkin`)
      .set(auth(driver.accessToken))
      .send({ checkinPin: '0000' });
    expect(wrongPin.status).toBe(400);
    expect(wrongPin.body.error.code).toBe('INVALID_PIN');

    const checkin = await request(app)
      .post(`/api/v1/bookings/${booking2Id}/checkin`)
      .set(auth(driver.accessToken))
      .send({ checkinPin: ridePin });
    expect(checkin.status).toBe(200);
    expect(checkin.body.data.booking.status).toBe('CHECKED_IN');

    const start = await request(app)
      .post(`/api/v1/rides/${rideId}/start`)
      .set(auth(driver.accessToken));
    expect(start.status).toBe(200);
    expect(start.body.data.ride.status).toBe('STARTED');

    const complete = await request(app)
      .post(`/api/v1/rides/${rideId}/complete`)
      .set(auth(driver.accessToken));
    expect(complete.status).toBe(200);
    expect(complete.body.data.ride.status).toBe('COMPLETED');

    const getRes = await request(app)
      .get(`/api/v1/rides/${rideId}`)
      .set(auth(student1.accessToken));
    expect(getRes.status).toBe(200);
    expect(getRes.body.data.ride.status).toBe('COMPLETED');
  }, 30_000);

  it('blocks non-drivers from managing a ride', async () => {
    const driver = await apiLogin('driver1@campusride.test');
    const student = await registerStudent();
    const campuses = await fetchCampuses();
    const vehicle = await fetchDriverVehicle(driver.accessToken, driver.userId);
    const date = tomorrowDate();

    const createRes = await request(app)
      .post('/api/v1/rides')
      .set(auth(driver.accessToken))
      .send({
        vehicleId: vehicle.id,
        originCampusId: campuses[0].id,
        destinationCampusId: campuses[1].id,
        origin: campuses[0].name,
        destination: campuses[1].name,
        departureAt: `${date}T09:00:00.000Z`,
        availableSeats: 1,
        pricePerSeat: 150,
      });
    const rideId = createRes.body.data.ride.id;

    const cancel = await request(app)
      .post(`/api/v1/rides/${rideId}/cancel`)
      .set(auth(student.accessToken));
    expect(cancel.status).toBe(403);
  });
});