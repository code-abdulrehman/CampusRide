import { Prisma, type NotificationType } from '@prisma/client';
import { prisma } from '../config/prisma.js';
import { buildEvent, EventTypes, userChannel } from '../realtime/events.js';
import { hub } from '../realtime/realtime-publisher.js';

export interface NotificationInput {
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: Prisma.InputJsonValue;
}

export async function createNotification(input: NotificationInput) {
  const notification = await prisma.notification.create({
    data: {
      userId: input.userId,
      type: input.type,
      title: input.title,
      body: input.body,
      data: input.data ?? {},
    },
  });
  hub.publish(
    userChannel(input.userId),
    buildEvent(EventTypes.NotificationCreated, { notification }),
  );
  return notification;
}

export interface Paged {
  page: number;
  pageSize: number;
}

export async function listNotifications(userId: string, { page, pageSize }: Paged) {
  const [items, total] = await Promise.all([
    prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    }),
    prisma.notification.count({ where: { userId } }),
  ]);
  return { items, total, page, pageSize };
}

export async function markNotificationRead(userId: string, notificationId: string) {
  const notification = await prisma.notification.findFirst({
    where: { id: notificationId, userId },
  });
  if (!notification) return null;
  return prisma.notification.update({
    where: { id: notificationId },
    data: { readAt: new Date() },
  });
}

export async function markAllNotificationsRead(userId: string) {
  await prisma.notification.updateMany({
    where: { userId, readAt: null },
    data: { readAt: new Date() },
  });
}

export async function unreadNotificationsCount(userId: string): Promise<number> {
  return prisma.notification.count({ where: { userId, readAt: null } });
}