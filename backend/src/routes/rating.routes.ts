import { Router } from 'express';
import * as ratingController from '../controllers/rating.controller.js';
import { requireAuth } from '../middleware/auth.middleware.js';
import { validateBody, validateParams } from '../middleware/validation.middleware.js';
import { rideIdParamSchema, userIdParamSchema } from '../validators/common.schema.js';
import { createRatingSchema } from '../validators/rating.schema.js';

export const ratingRouter = Router();

ratingRouter.post(
  '/rides/:rideId/ratings',
  requireAuth,
  validateParams(rideIdParamSchema),
  validateBody(createRatingSchema),
  ratingController.createRating,
);
ratingRouter.get(
  '/users/:userId/ratings',
  requireAuth,
  validateParams(userIdParamSchema),
  ratingController.ratingsForUser,
);