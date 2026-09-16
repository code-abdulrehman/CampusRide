import { Router } from 'express';
import * as notificationController from '../controllers/notification.controller.js';
import { requireAuth } from '../middleware/auth.middleware.js';
import { validateParams } from '../middleware/validation.middleware.js';
import { idParamSchema } from '../validators/common.schema.js';

export const notificationRouter = Router();

notificationRouter.use(requireAuth);

notificationRouter.get('/', notificationController.listNotifications);
notificationRouter.patch(
  '/:id/read',
  validateParams(idParamSchema),
  notificationController.markRead,
);
notificationRouter.post('/read-all', notificationController.markAllRead);