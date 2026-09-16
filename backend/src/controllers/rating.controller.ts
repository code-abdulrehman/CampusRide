import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as ratingService from '../services/rating.service.js';

export const createRating: RequestHandler = async (req, res, next) => {
  try {
    const result = await ratingService.createRating(
      req.user!.userId,
      req.params.rideId as string,
      req.body,
    );
    res.status(201).json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const ratingsForUser: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await ratingService.ratingsForUser(req.params.userId as string)));
  } catch (err) {
    next(err);
  }
};