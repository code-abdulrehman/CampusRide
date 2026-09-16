import { Router } from 'express';
import * as vehicleController from '../controllers/vehicle.controller.js';
import { requireAuth } from '../middleware/auth.middleware.js';
import { validateBody, validateParams } from '../middleware/validation.middleware.js';
import { vehicleIdParamSchema } from '../validators/common.schema.js';
import { createVehicleSchema, updateVehicleSchema } from '../validators/vehicle.schema.js';

export const vehicleRouter = Router();

vehicleRouter.use(requireAuth);

vehicleRouter.get('/me', vehicleController.listMyVehicles);
vehicleRouter.post('/', validateBody(createVehicleSchema), vehicleController.createVehicle);
vehicleRouter.patch(
  '/:vehicleId',
  validateParams(vehicleIdParamSchema),
  validateBody(updateVehicleSchema),
  vehicleController.updateVehicle,
);
vehicleRouter.delete(
  '/:vehicleId',
  validateParams(vehicleIdParamSchema),
  vehicleController.deleteVehicle,
);