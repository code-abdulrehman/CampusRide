import { Router } from 'express';
import * as rideController from '../controllers/ride.controller.js';
import { requireAuth } from '../middleware/auth.middleware.js';
import { validateBody, validateParams, validateQuery } from '../middleware/validation.middleware.js';
import { rideIdParamSchema } from '../validators/common.schema.js';
import { createRideSchema, searchRideQuerySchema, updateRideSchema } from '../validators/ride.schema.js';

export const rideRouter = Router();

rideRouter.use(requireAuth);

rideRouter.get('/search', validateQuery(searchRideQuerySchema), rideController.searchRides);
rideRouter.get('/mine', rideController.myRides);
rideRouter.post('/', validateBody(createRideSchema), rideController.createRide);
rideRouter.get('/:rideId', validateParams(rideIdParamSchema), rideController.getRide);
rideRouter.patch(
  '/:rideId',
  validateParams(rideIdParamSchema),
  validateBody(updateRideSchema),
  rideController.updateRide,
);
rideRouter.post(
  '/:rideId/cancel',
  validateParams(rideIdParamSchema),
  rideController.cancelRide,
);
rideRouter.post(
  '/:rideId/start',
  validateParams(rideIdParamSchema),
  rideController.startRide,
);
rideRouter.post(
  '/:rideId/complete',
  validateParams(rideIdParamSchema),
  rideController.completeRide,
);
rideRouter.get(
  '/:rideId/location/latest',
  validateParams(rideIdParamSchema),
  rideController.latestLocation,
);