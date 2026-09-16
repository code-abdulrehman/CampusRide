import { Prisma, type NotificationType, type Role } from '@prisma/client';
import { createNotification } from '../../services/notification.service.js';
import { prisma } from '../../config/prisma.js';

export function logAudit(
  actorUserId: string | null,
  action: string,
  entityType: string,
  entityId: string,
  metadata?: Record<string, unknown>,
): Promise<unknown> {
  return prisma.auditLog.create({
    data: {
      actorUserId,
      action,
      entityType,
      entityId,
      metadata: (metadata ?? {}) as Prisma.InputJsonValue,
    },
  });
}

export async function notifyUsersByRole(
  role: Role[],
  type: NotificationType,
  title: string,
  body: string,
  data?: Prisma.InputJsonValue,
): Promise<void> {
  const admins = await prisma.user.findMany({
    where: { role: { in: role }, accountStatus: 'ACTIVE' },
    select: { id: true },
  });
  await Promise.all(
    admins.map((admin) => createNotification({ userId: admin.id, type, title, body, data })),
  );
}