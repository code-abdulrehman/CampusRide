import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as campusService from '../services/campus.service.js';

export const listCampuses: RequestHandler = async (_req, res, next) => {
  try {
    res.json(ok(await campusService.listCampuses()));
  } catch (err) {
    next(err);
  }
};

export const getCampus: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await campusService.getCampus(req.params.id as string)));
  } catch (err) {
    next(err);
  }
};