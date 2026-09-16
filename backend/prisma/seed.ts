import {
  PrismaClient,
  Role,
  VerificationStatus,
  RideStatus,
  RideRequestStatus,
  BookingStatus,
  ReportReason,
  ReportStatus,
  NotificationType,
  VehicleType,
} from '@prisma/client';
import argon2 from 'argon2';

const prisma = new PrismaClient();

const PASSWORD = 'CampusRide@123';
const CHECKIN_PIN = '1234';

const hoursFromNow = (h: number) => new Date(Date.now() + h * 3_600_000);
const daysFromNow = (d: number) => new Date(Date.now() + d * 86_400_000);

interface SeedUserData {
  email: string;
  fullName: string;
  role: Role;
  studentId: string;
  driverVerified?: VerificationStatus;
  accountStatus?: 'ACTIVE' | 'SUSPENDED';
  mainCampusId?: string;
}

async function main() {
  await prisma.$transaction([
    prisma.rideLocation.deleteMany(),
    prisma.auditLog.deleteMany(),
    prisma.refreshToken.deleteMany(),
    prisma.notification.deleteMany(),
    prisma.report.deleteMany(),
    prisma.rating.deleteMany(),
    prisma.booking.deleteMany(),
    prisma.rideRequest.deleteMany(),
    prisma.ride.deleteMany(),
    prisma.vehicle.deleteMany(),
    prisma.user.deleteMany(),
    prisma.campus.deleteMany(),
  ]);

  const passwordHash = await argon2.hash(PASSWORD, { type: argon2.argon2id });
  const pinHash = await argon2.hash(CHECKIN_PIN, { type: argon2.argon2id });

  const [mainCampus, campusA, campusB, campusC] = await Promise.all([
    prisma.campus.create({
      data: {
        name: 'Main Campus',
        code: 'MAIN',
        address: 'University Main Campus, Lahore',
        latitude: 31.4697,
        longitude: 74.2962,
        securityContact: '+923001234001',
        openingHour: 8,
        closingHour: 20,
      },
    }),
    prisma.campus.create({
      data: {
        name: 'Campus A',
        code: 'CAMPUS_A',
        address: 'Campus A Road, Lahore',
        latitude: 31.4925,
        longitude: 74.2888,
        securityContact: '+923001234002',
        openingHour: 8,
        closingHour: 20,
      },
    }),
    prisma.campus.create({
      data: {
        name: 'Campus B',
        code: 'CAMPUS_B',
        address: 'Campus B Road, Lahore',
        latitude: 31.4784,
        longitude: 74.3305,
        securityContact: '+923001234003',
        openingHour: 8,
        closingHour: 20,
      },
    }),
    prisma.campus.create({
      data: {
        name: 'Campus C',
        code: 'CAMPUS_C',
        address: 'Campus C Road, Lahore',
        latitude: 31.4262,
        longitude: 74.3478,
        securityContact: '+923001234004',
        openingHour: 8,
        closingHour: 20,
      },
    }),
  ]);

  async function createUser(data: SeedUserData) {
    return prisma.user.create({
      data: {
        email: data.email,
        passwordHash,
        fullName: data.fullName,
        role: data.role,
        studentId: data.studentId,
        mainCampusId: data.mainCampusId ?? mainCampus.id,
        studentVerified: VerificationStatus.VERIFIED,
        driverVerified: data.driverVerified ?? VerificationStatus.PENDING,
        accountStatus: data.accountStatus ?? 'ACTIVE',
        avatarKey: data.studentId === 'ADMIN-0001' ? 'avatar_01' : undefined,
      },
    });
  }

  const admin = await createUser({
    email: 'admin@campusride.test',
    fullName: 'System Admin',
    role: Role.ADMIN,
    studentId: 'ADMIN-0001',
  });
  const superAdmin = await createUser({
    email: 'superadmin@campusride.test',
    fullName: 'Super Admin',
    role: Role.SUPER_ADMIN,
    studentId: 'ADMIN-0000',
  });
  const student1 = await createUser({
    email: 'student1@campusride.test',
    fullName: 'Student One',
    role: Role.STUDENT,
    studentId: 'STU-1001',
    mainCampusId: campusA.id,
  });
  const student2 = await createUser({
    email: 'student2@campusride.test',
    fullName: 'Student Two',
    role: Role.STUDENT,
    studentId: 'STU-1002',
    mainCampusId: mainCampus.id,
  });
  const driver1 = await createUser({
    email: 'driver1@campusride.test',
    fullName: 'Driver One',
    role: Role.STUDENT,
    studentId: 'STU-2001',
    driverVerified: VerificationStatus.VERIFIED,
    mainCampusId: mainCampus.id,
  });
  const driver2 = await createUser({
    email: 'driver2@campusride.test',
    fullName: 'Driver Two',
    role: Role.STUDENT,
    studentId: 'STU-2002',
    driverVerified: VerificationStatus.VERIFIED,
    mainCampusId: campusB.id,
  });
  const driverPending = await createUser({
    email: 'driverpending@campusride.test',
    fullName: 'Driver Pending',
    role: Role.STUDENT,
    studentId: 'STU-2003',
    driverVerified: VerificationStatus.PENDING,
    mainCampusId: mainCampus.id,
  });

  const [car1, car2, car3] = await Promise.all([
    prisma.vehicle.create({
      data: {
        ownerId: driver1.id,
        vehicleType: VehicleType.HATCHBACK,
        company: 'Suzuki',
        model: 'WagonR',
        year: 2022,
        color: 'White',
        registrationNumber: 'LEP-1234',
        totalSeats: 5,
        passengerCapacity: 4,
        verificationStatus: VerificationStatus.VERIFIED,
      },
    }),
    prisma.vehicle.create({
      data: {
        ownerId: driver1.id,
        vehicleType: VehicleType.SUV,
        company: 'Toyota',
        model: 'Fortuner',
        year: 2021,
        color: 'Black',
        registrationNumber: 'LEP-5678',
        totalSeats: 7,
        passengerCapacity: 6,
        verificationStatus: VerificationStatus.VERIFIED,
      },
    }),
    prisma.vehicle.create({
      data: {
        ownerId: driver2.id,
        vehicleType: VehicleType.SEDAN,
        company: 'Honda',
        model: 'Civic',
        year: 2023,
        color: 'White',
        registrationNumber: 'LEP-9101',
        totalSeats: 5,
        passengerCapacity: 4,
        verificationStatus: VerificationStatus.VERIFIED,
      },
    }),
  ]);

  const [rideOpen3, rideOpen1, rideFull, rideStarted, rideCompleted] =
    await Promise.all([
      prisma.ride.create({
        data: {
          driverId: driver1.id,
          vehicleId: car1.id,
          origin: 'Main Campus',
          destination: 'Campus A',
          originCampusId: mainCampus.id,
          destinationCampusId: campusA.id,
          departureAt: hoursFromNow(2),
          expectedArrivalAt: new Date(hoursFromNow(2).getTime() + 45 * 60_000),
          availableSeats: 3,
          pricePerSeat: 200,
          pickupRadiusKm: 2,
          maxDetourMinutes: 20,
          conditions: ['no_smoking'],
          notes: 'Pickup near main gate.',
          recurring: false,
          recurringDays: [],
          ridePin: '1001',
          status: RideStatus.OPEN,
        },
      }),
      prisma.ride.create({
        data: {
          driverId: driver2.id,
          vehicleId: car3.id,
          origin: 'Campus B',
          destination: 'Main Campus',
          originCampusId: campusB.id,
          destinationCampusId: mainCampus.id,
          departureAt: hoursFromNow(4),
          expectedArrivalAt: new Date(hoursFromNow(4).getTime() + 40 * 60_000),
          availableSeats: 1,
          pricePerSeat: 250,
          pickupRadiusKm: 1.5,
          maxDetourMinutes: 15,
          conditions: [],
          notes: 'Please be on time.',
          recurring: false,
          recurringDays: [],
          ridePin: '1002',
          status: RideStatus.OPEN,
        },
      }),
      prisma.ride.create({
        data: {
          driverId: driver1.id,
          vehicleId: car2.id,
          origin: 'Main Campus',
          destination: 'Campus C',
          originCampusId: mainCampus.id,
          destinationCampusId: campusC.id,
          departureAt: hoursFromNow(6),
          expectedArrivalAt: new Date(hoursFromNow(6).getTime() + 50 * 60_000),
          availableSeats: 0,
          pricePerSeat: 300,
          pickupRadiusKm: 2,
          maxDetourMinutes: 25,
          conditions: ['no_smoking', 'quiet_ride'],
          notes: '',
          recurring: false,
          recurringDays: [],
          ridePin: '1003',
          status: RideStatus.FULL,
        },
      }),
      prisma.ride.create({
        data: {
          driverId: driver1.id,
          vehicleId: car1.id,
          origin: 'Main Campus',
          destination: 'Campus B',
          originCampusId: mainCampus.id,
          destinationCampusId: campusB.id,
          departureAt: hoursFromNow(-1),
          expectedArrivalAt: hoursFromNow(-1),
          availableSeats: 0,
          pricePerSeat: 200,
          pickupRadiusKm: 2,
          maxDetourMinutes: 20,
          conditions: [],
          notes: 'Weekly ride.',
          recurring: false,
          recurringDays: [],
          ridePin: '1004',
          status: RideStatus.STARTED,
        },
      }),
      prisma.ride.create({
        data: {
          driverId: driver2.id,
          vehicleId: car3.id,
          origin: 'Campus A',
          destination: 'Main Campus',
          originCampusId: campusA.id,
          destinationCampusId: mainCampus.id,
          departureAt: daysFromNow(-1),
          expectedArrivalAt: new Date(daysFromNow(-1).getTime() + 40 * 60_000),
          availableSeats: 0,
          pricePerSeat: 220,
          pickupRadiusKm: 2,
          maxDetourMinutes: 15,
          conditions: [],
          notes: '',
          recurring: false,
          recurringDays: [],
          ridePin: '1005',
          status: RideStatus.COMPLETED,
        },
      }),
    ]);

  const [request1, request2, request3] = await Promise.all([
    prisma.rideRequest.create({
      data: {
        studentId: student1.id,
        originCampusId: mainCampus.id,
        destinationCampusId: campusB.id,
        earliestDeparture: hoursFromNow(2),
        latestDeparture: hoursFromNow(3),
        requiredSeats: 1,
        maxBudget: 250,
        maxPickupDistanceKm: 2,
        status: RideRequestStatus.OPEN,
      },
    }),
    prisma.rideRequest.create({
      data: {
        studentId: student2.id,
        originCampusId: campusA.id,
        destinationCampusId: mainCampus.id,
        earliestDeparture: hoursFromNow(5),
        latestDeparture: hoursFromNow(6),
        requiredSeats: 2,
        maxBudget: 300,
        maxPickupDistanceKm: 3,
        status: RideRequestStatus.OPEN,
      },
    }),
    prisma.rideRequest.create({
      data: {
        studentId: student1.id,
        originCampusId: mainCampus.id,
        destinationCampusId: campusA.id,
        earliestDeparture: daysFromNow(-1),
        latestDeparture: new Date(daysFromNow(-1).getTime() + 60 * 60_000),
        requiredSeats: 1,
        maxBudget: 200,
        maxPickupDistanceKm: 2,
        status: RideRequestStatus.MATCHED,
      },
    }),
  ]);

  await Promise.all([
    prisma.booking.create({
      data: {
        rideId: rideOpen3.id,
        passengerId: student2.id,
        seats: 1,
        status: BookingStatus.REQUESTED,
        requestedAt: hoursFromNow(-0.25),
      },
    }),
    prisma.booking.create({
      data: {
        rideId: rideOpen1.id,
        passengerId: student1.id,
        seats: 1,
        status: BookingStatus.ACCEPTED,
        checkinPinHash: pinHash,
        requestedAt: hoursFromNow(-2),
        acceptedAt: hoursFromNow(-1.5),
      },
    }),
    prisma.booking.create({
      data: {
        rideId: rideOpen3.id,
        passengerId: student1.id,
        seats: 1,
        status: BookingStatus.CANCELLED,
        requestedAt: hoursFromNow(-6),
        acceptedAt: hoursFromNow(-5.5),
        cancelledAt: hoursFromNow(-5),
      },
    }),
    prisma.booking.create({
      data: {
        rideId: rideCompleted.id,
        passengerId: student2.id,
        seats: 1,
        status: BookingStatus.COMPLETED,
        requestedAt: new Date(daysFromNow(-1).getTime() - 2 * 3_600_000),
        acceptedAt: new Date(daysFromNow(-1).getTime() - 1.5 * 3_600_000),
        checkedInAt: new Date(daysFromNow(-1).getTime() - 45 * 60_000),
        completedAt: new Date(daysFromNow(-1).getTime() + 50 * 60_000),
      },
    }),
  ]);

  await prisma.rating.create({
    data: {
      rideId: rideCompleted.id,
      reviewerId: student2.id,
      revieweeId: driver2.id,
      overall: 5,
      punctuality: 5,
      behaviour: 4,
      communication: 5,
      comment: 'Great ride, very punctual.',
    },
  });

  await prisma.report.create({
    data: {
      reporterId: student1.id,
      reportedUserId: driverPending.id,
      reason: ReportReason.NO_SHOW,
      details: 'Driver did not show up at the pickup point.',
      status: ReportStatus.OPEN,
    },
  });

  await Promise.all([
    prisma.notification.create({
      data: {
        userId: driver1.id,
        type: NotificationType.BOOKING_REQUEST,
        title: 'New booking request',
        body: `${student2.fullName} requested 1 seat on your ride to Campus A.`,
        data: { rideId: rideOpen3.id },
      },
    }),
    prisma.notification.create({
      data: {
        userId: student1.id,
        type: NotificationType.BOOKING_ACCEPTED,
        title: 'Booking accepted',
        body: 'Your seat on the ride to Main Campus was accepted.',
        data: { rideId: rideOpen1.id },
      },
    }),
    prisma.notification.create({
      data: {
        userId: student2.id,
        type: NotificationType.RIDE_COMPLETED,
        title: 'Ride completed',
        body: 'Your ride was completed. Please leave a rating.',
        data: { rideId: rideCompleted.id },
        readAt: new Date(),
      },
    }),
  ]);

  await Promise.all([
    prisma.auditLog.create({
      data: {
        actorUserId: admin.id,
        action: 'SEED_ONBOARD',
        entityType: 'campus',
        entityId: mainCampus.id,
        metadata: { note: 'Seed data created' },
      },
    }),
    prisma.auditLog.create({
      data: {
        actorUserId: admin.id,
        action: 'VERIFY_DRIVER',
        entityType: 'user',
        entityId: driver1.id,
        metadata: { verification: 'VERIFIED' },
      },
    }),
  ]);

  console.log('Seed complete.');
  console.log(`Password for all users: ${PASSWORD}`);
  console.log(
    `Logins: admin@campusride.test, student1@campusride.test, student2@campusride.test, driver1@campusride.test, driver2@campusride.test`,
  );
}

main()
  .catch((err) => {
    console.error('Seed failed:', err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });