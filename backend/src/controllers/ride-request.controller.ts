import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as rideRequestService from '../services/ride-request.service.js';

export const createRideRequest: RequestHandler = async (req, res, next) => {
  try {
    const result = await rideRequestService.createRideRequest(req.user!.userId, req.body);
    res.status(201).json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const myRideRequests: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await rideRequestService.myRideRequests(req.user!.userId)));
  } catch (err) {
    next(err);
  }
};

export const getRideRequest: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideRequestService.getRideRequest(req.user!.userId, req.params.id as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const updateRideRequest: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideRequestService.updateRideRequest(req.user!.userId, req.params.id as string, req.body)),
    );
  } catch (err) {
    next(err);
  }
};

export const cancelRideRequest: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideRequestService.cancelRideRequest(req.user!.userId, req.params.id as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const rideRequestMatches: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await rideRequestService.getRideRequestMatches(req.user!.userId, req.params.id as string)),
    );
  } catch (err) {
    next(err);
  }
};