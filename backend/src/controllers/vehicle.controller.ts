import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as vehicleService from '../services/vehicle.service.js';

export const listMyVehicles: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await vehicleService.listMyVehicles(req.user!.userId)));
  } catch (err) {
    next(err);
  }
};

export const createVehicle: RequestHandler = async (req, res, next) => {
  try {
    const vehicle = await vehicleService.createVehicle(req.user!.userId, req.body);
    res.status(201).json(ok(vehicle));
  } catch (err) {
    next(err);
  }
};

export const updateVehicle: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await vehicleService.updateOwnVehicle(req.user!.userId, req.params.vehicleId as string, req.body)),
    );
  } catch (err) {
    next(err);
  }
};

export const deleteVehicle: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await vehicleService.deactivateOwnVehicle(req.user!.userId, req.params.vehicleId as string)),
    );
  } catch (err) {
    next(err);
  }
};