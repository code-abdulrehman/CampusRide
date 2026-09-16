import { Role } from '@prisma/client';
import { Router } from 'express';
import * as adminController from '../controllers/admin.controller.js';
import { requireAuth, requireRole } from '../middleware/auth.middleware.js';
import { validateBody, validateParams } from '../middleware/validation.middleware.js';
import { idParamSchema, userIdParamSchema, vehicleIdParamSchema } from '../validators/common.schema.js';
import { resolveReportSchema, setUserStatusSchema, verifyUserSchema } from '../validators/admin.schema.js';

export const adminRouter = Router();

adminRouter.use(requireAuth, requireRole(Role.ADMIN, Role.SUPER_ADMIN));

adminRouter.get('/dashboard', adminController.dashboard);
adminRouter.get('/users', adminController.listUsers);
adminRouter.patch(
  '/users/:userId/status',
  validateParams(userIdParamSchema),
  validateBody(setUserStatusSchema),
  adminController.setUserStatus,
);
adminRouter.get('/drivers/pending', adminController.pendingDrivers);
adminRouter.patch(
  '/drivers/:userId/verification',
  validateParams(userIdParamSchema),
  validateBody(verifyUserSchema),
  adminController.verifyDriver,
);
adminRouter.get('/vehicles/pending', adminController.pendingVehicles);
adminRouter.patch(
  '/vehicles/:vehicleId/verification',
  validateParams(vehicleIdParamSchema),
  validateBody(verifyUserSchema),
  adminController.verifyVehicle,
);
adminRouter.get('/reports', adminController.listReports);
adminRouter.patch(
  '/reports/:id',
  validateParams(idParamSchema),
  validateBody(resolveReportSchema),
  adminController.resolveReport,
);