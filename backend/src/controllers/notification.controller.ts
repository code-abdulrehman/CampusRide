import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as notificationService from '../services/notification.service.js';

export const listNotifications: RequestHandler = async (req, res, next) => {
  try {
    const page = Number(req.query.page ?? 1);
    const pageSize = Number(req.query.pageSize ?? 20);
    res.json(
      ok(
        await notificationService.listNotifications(req.user!.userId, { page, pageSize }),
      ),
    );
  } catch (err) {
    next(err);
  }
};

export const markRead: RequestHandler = async (req, res, next) => {
  try {
    const result = await notificationService.markNotificationRead(
      req.user!.userId,
      req.params.id as string,
    );
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const markAllRead: RequestHandler = async (req, res, next) => {
  try {
    await notificationService.markAllNotificationsRead(req.user!.userId);
    res.json(ok(null));
  } catch (err) {
    next(err);
  }
};