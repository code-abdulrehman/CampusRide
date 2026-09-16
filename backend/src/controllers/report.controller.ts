import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as reportService from '../services/report.service.js';

export const createReport: RequestHandler = async (req, res, next) => {
  try {
    const result = await reportService.createReport(req.user!.userId, req.body);
    res.status(201).json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const myReports: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await reportService.myReports(req.user!.userId)));
  } catch (err) {
    next(err);
  }
};