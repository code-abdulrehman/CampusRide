import { AccountStatus, ReportStatus, Role, VerificationStatus } from '@prisma/client';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { toPublicUser, toVehicle } from '../common/utils/serializers.js';
import { logAudit } from '../common/utils/audit.js';
import { prisma } from '../config/prisma.js';
import { createNotification } from './notification.service.js';
import { buildEvent, adminChannel, EventTypes, userChannel } from '../realtime/events.js';
import { hub } from '../realtime/realtime-publisher.js';

export async function dashboardSummary() {
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const [totalUsers, totalStudents, driversPending, vehiclesPending, openReports, activeRides, ridesToday, totalRides, suspendedUsers] =
    await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { role: Role.STUDENT, studentVerified: VerificationStatus.VERIFIED } }),
      prisma.user.count({ where: { driverVerified: VerificationStatus.PENDING } }),
      prisma.vehicle.count({ where: { verificationStatus: VerificationStatus.PENDING } }),
      prisma.report.count({ where: { status: ReportStatus.OPEN } }),
      prisma.ride.count({ where: { status: { in: ['OPEN', 'FULL', 'STARTED'] } } }),
      prisma.ride.count({ where: { departureAt: { gte: startOfDay } } }),
      prisma.ride.count(),
      prisma.user.count({ where: { accountStatus: AccountStatus.SUSPENDED } }),
    ]);
  return {
    totalUsers,
    totalStudents,
    driversPending,
    vehiclesPending,
    openReports,
    activeRides,
    ridesToday,
    totalRides,
    suspendedUsers,
  };
}

export interface ListUsersParams {
  query?: string;
  role?: Role;
  page: number;
  pageSize: number;
}

export async function listUsers({ query, role, page, pageSize }: ListUsersParams) {
  const where = {
    ...(role ? { role } : {}),
    ...(query
      ? {
          OR: [
            { fullName: { contains: query, mode: 'insensitive' as const } },
            { email: { contains: query, mode: 'insensitive' as const } },
            { studentId: { contains: query, mode: 'insensitive' as const } },
          ],
        }
      : {}),
  };
  const [items, total] = await Promise.all([
    prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    }),
    prisma.user.count({ where }),
  ]);
  return { items: items.map(toPublicUser), total, page, pageSize };
}

export async function setUserStatus(actorId: string, userId: string, accountStatus: AccountStatus) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'User not found');
  const updated = await prisma.user.update({
    where: { id: userId },
    data: { accountStatus },
  });
  await logAudit(actorId, 'SET_USER_STATUS', 'user', userId, {
    from: user.accountStatus,
    to: accountStatus,
  });
  await createNotification({
    userId,
    type: 'ACCOUNT_STATUS',
    title: accountStatus === 'SUSPENDED' ? 'Account suspended' : 'Account restored',
    body:
      accountStatus === 'SUSPENDED'
        ? 'Your account has been suspended. Contact support for details.'
        : 'Your account has been reactivated.',
  });
  hub.publish(
    userChannel(userId),
    buildEvent(EventTypes.AccountStatusUpdated, { userId, accountStatus }),
  );
  return toPublicUser(updated);
}

export async function listPendingDrivers() {
  const users = await prisma.user.findMany({
    where: { driverVerified: VerificationStatus.PENDING },
    orderBy: { createdAt: 'asc' },
    include: {
      _count: { select: { vehicles: true } },
    },
  });
  return users.map((u) => ({ ...toPublicUser(u), vehicleCount: u._count.vehicles }));
}

export async function verifyDriver(actorId: string, userId: string, status: VerificationStatus) {
  if (uid(actorId) === uid(userId)) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'Admins cannot verify themselves');
  }
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'User not found');
  const updated = await prisma.user.update({
    where: { id: userId },
    data: { driverVerified: status },
  });
  await logAudit(actorId, 'VERIFY_DRIVER', 'user', userId, { status });
  await createNotification({
    userId,
    type: 'VERIFICATION_UPDATED',
    title: `Driver verification ${status.toLowerCase()}`,
    body:
      status === 'VERIFIED'
        ? 'Your driver account has been verified. You can now offer rides.'
        : status === 'REJECTED'
          ? 'Your driver verification was rejected. Please contact support.'
          : 'Your driver verification is pending review.',
  });
  hub.publish(
    userChannel(userId),
    buildEvent(EventTypes.VerificationUpdated, { userId, driverVerified: status }),
  );
  return toPublicUser(updated);
}

export async function listPendingVehicles() {
  const vehicles = await prisma.vehicle.findMany({
    where: { verificationStatus: VerificationStatus.PENDING, active: true },
    orderBy: { createdAt: 'asc' },
    include: {
      owner: {
        select: {
          id: true,
          fullName: true,
          email: true,
          driverVerified: true,
        },
      },
    },
  });
  return vehicles.map((v) => ({ ...toVehicle(v), owner: v.owner }));
}

export async function verifyVehicle(actorId: string, vehicleId: string, status: VerificationStatus) {
  const vehicle = await prisma.vehicle.findUnique({
    where: { id: vehicleId },
    include: { owner: { select: { id: true } } },
  });
  if (!vehicle) throw new ApiError(404, ErrorCodes.VEHICLE_NOT_FOUND, 'Vehicle not found');
  const updated = await prisma.vehicle.update({
    where: { id: vehicleId },
    data: { verificationStatus: status },
  });
  await logAudit(actorId, 'VERIFY_VEHICLE', 'vehicle', vehicleId, { status });
  await createNotification({
    userId: vehicle.owner.id,
    type: 'VERIFICATION_UPDATED',
    title: `Vehicle verification ${status.toLowerCase()}`,
    body:
      status === 'VERIFIED'
        ? `Your vehicle ${vehicle.company} ${vehicle.model} was verified.`
        : status === 'REJECTED'
          ? `Your vehicle ${vehicle.company} ${vehicle.model} verification was rejected.`
          : `Your vehicle ${vehicle.company} ${vehicle.model} verification is pending.`,
  });
  hub.publish(
    adminChannel,
    buildEvent(EventTypes.VerificationUpdated, { vehicleId, verificationStatus: status }),
  );
  return toVehicle(updated);
}

export interface ListReportsParams {
  status?: ReportStatus;
  page: number;
  pageSize: number;
}

export async function listReports({ status, page, pageSize }: ListReportsParams) {
  const where = status ? { status } : {};
  const [items, total] = await Promise.all([
    prisma.report.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * pageSize,
      take: pageSize,
      include: {
        reporter: { select: { id: true, fullName: true, email: true } },
        reportedUser: { select: { id: true, fullName: true, email: true } },
        ride: { select: { id: true, origin: true, destination: true } },
      },
    }),
    prisma.report.count({ where }),
  ]);
  return { items, total, page, pageSize };
}

export async function resolveReport(
  actorId: string,
  reportId: string,
  status: ReportStatus,
  adminAction?: string,
) {
  const report = await prisma.report.findUnique({ where: { id: reportId } });
  if (!report) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'Report not found');
  const updated = await prisma.report.update({
    where: { id: reportId },
    data: {
      status,
      adminAction: adminAction ?? null,
      resolvedBy: actorId,
      resolvedAt: new Date(),
    },
  });
  await logAudit(actorId, 'RESOLVE_REPORT', 'report', reportId, { status, adminAction });
  hub.publish(
    adminChannel,
    buildEvent('report.resolved', { reportId, status }),
  );
  return updated;
}

function uid(value: string): string {
  return value.trim().toLowerCase();
}