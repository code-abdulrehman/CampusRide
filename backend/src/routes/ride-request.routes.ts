import { Router } from 'express';
import * as rideRequestController from '../controllers/ride-request.controller.js';
import { requireAuth } from '../middleware/auth.middleware.js';
import { validateBody, validateParams } from '../middleware/validation.middleware.js';
import { idParamSchema } from '../validators/common.schema.js';
import { createRideRequestSchema, updateRideRequestSchema } from '../validators/ride.schema.js';

export const rideRequestRouter = Router();

rideRequestRouter.use(requireAuth);

rideRequestRouter.get('/mine', rideRequestController.myRideRequests);
rideRequestRouter.post(
  '/',
  validateBody(createRideRequestSchema),
  rideRequestController.createRideRequest,
);
rideRequestRouter.get('/:id', validateParams(idParamSchema), rideRequestController.getRideRequest);
rideRequestRouter.patch(
  '/:id',
  validateParams(idParamSchema),
  validateBody(updateRideRequestSchema),
  rideRequestController.updateRideRequest,
);
rideRequestRouter.post(
  '/:id/cancel',
  validateParams(idParamSchema),
  rideRequestController.cancelRideRequest,
);
rideRequestRouter.get(
  '/:id/matches',
  validateParams(idParamSchema),
  rideRequestController.rideRequestMatches,
);