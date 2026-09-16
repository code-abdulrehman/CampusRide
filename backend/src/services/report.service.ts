import { ReportStatus, Role } from '@prisma/client';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { prisma } from '../config/prisma.js';
import { createNotification } from './notification.service.js';
import { buildEvent, adminChannel, EventTypes } from '../realtime/events.js';
import { hub } from '../realtime/realtime-publisher.js';

export interface CreateReportInput {
  reportedUserId?: string;
  rideId?: string;
  reason: string;
  details: string;
}

const reasons = [
  'DANGEROUS_DRIVING',
  'HARASSMENT',
  'FAKE_DETAILS',
  'NO_SHOW',
  'EXCESSIVE_CHARGING',
  'MISBEHAVIOR',
  'WRONG_PICKUP',
  'SPAM',
  'OTHER',
] as const;

export async function createReport(userId: string, input: CreateReportInput) {
  if (!reasons.includes(input.reason as (typeof reasons)[number])) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'Invalid report reason');
  }
  if (input.reportedUserId === userId) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'You cannot report yourself');
  }
  if (input.reportedUserId) {
    const reported = await prisma.user.findUnique({ where: { id: input.reportedUserId } });
    if (!reported) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'Reported user not found');
  }
  if (input.rideId) {
    const ride = await prisma.ride.findUnique({ where: { id: input.rideId } });
    if (!ride) throw new ApiError(404, ErrorCodes.RIDE_NOT_FOUND, 'Ride not found');
  }

  const report = await prisma.report.create({
    data: {
      reporterId: userId,
      reportedUserId: input.reportedUserId ?? null,
      rideId: input.rideId ?? null,
      reason: input.reason as (typeof reasons)[number],
      details: input.details,
      status: ReportStatus.OPEN,
    },
  });

  const admins = await prisma.user.findMany({
    where: { role: { in: [Role.ADMIN, Role.SUPER_ADMIN] }, accountStatus: 'ACTIVE' },
    select: { id: true },
  });
  await Promise.all(
    admins.map((admin) =>
      createNotification({
        userId: admin.id,
        type: 'GENERAL',
        title: 'New report',
        body: `A new ${input.reason.replaceAll('_', ' ').toLowerCase()} report was submitted.`,
        data: { reportId: report.id },
      }),
    ),
  );
  hub.publish(
    adminChannel,
    buildEvent(EventTypes.ReportCreated, { report: { id: report.id, reason: report.reason, status: report.status } }),
  );

  return {
    id: report.id,
    reporterId: report.reporterId,
    reportedUserId: report.reportedUserId,
    rideId: report.rideId,
    reason: report.reason,
    status: report.status,
    createdAt: report.createdAt,
  };
}

export async function myReports(userId: string) {
  const reports = await prisma.report.findMany({
    where: { reporterId: userId },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });
  return reports.map((r) => ({
    id: r.id,
    reportedUserId: r.reportedUserId,
    rideId: r.rideId,
    reason: r.reason,
    details: r.details,
    status: r.status,
    adminAction: r.adminAction,
    createdAt: r.createdAt,
    resolvedAt: r.resolvedAt,
  }));
}