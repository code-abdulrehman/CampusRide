import type { RequestHandler } from 'express';
import { ok, fail } from '../common/response/response.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { prisma } from '../config/prisma.js';
import * as rideService from '../services/ride.service.js';

export const createRide: RequestHandler = async (req, res, next) => {
  try {
    const result = await rideService.createRide(req.user!.userId, req.body);
    res.status(201).json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const searchRides: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideService.searchRides(req.query as unknown as Parameters<typeof rideService.searchRides>[0])),
    );
  } catch (err) {
    next(err);
  }
};

export const myRides: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await rideService.myRides(req.user!.userId)));
  } catch (err) {
    next(err);
  }
};

export const getRide: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideService.getRide(req.params.rideId as string, req.user!.userId)),
    );
  } catch (err) {
    next(err);
  }
};

export const updateRide: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideService.updateRide(req.user!.userId, req.params.rideId as string, req.body)),
    );
  } catch (err) {
    next(err);
  }
};

export const cancelRide: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideService.cancelRide(req.user!.userId, req.params.rideId as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const startRide: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(
        await rideService.startRide(
          req.user!.userId,
          req.params.rideId as string,
          (req.body as { checkinAll?: boolean } | undefined)?.checkinAll ?? false,
        ),
      ),
    );
  } catch (err) {
    next(err);
  }
};

export const completeRide: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideService.completeRide(req.user!.userId, req.params.rideId as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const latestLocation: RequestHandler = async (req, res, next) => {
  try {
    const location = await prisma.rideLocation.findUnique({
      where: {
        rideId_userId: {
          rideId: req.params.rideId as string,
          userId: req.user!.userId,
        },
      },
    });
    if (!location) {
      res.status(404).json(fail(ErrorCodes.NOT_FOUND, 'No location available yet'));
      return;
    }
    res.json(ok(location));
  } catch (err) {
    next(err);
  }
};