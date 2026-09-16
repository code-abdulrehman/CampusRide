import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as adminService from '../services/admin.service.js';

export const dashboard: RequestHandler = async (_req, res, next) => {
  try {
    res.json(ok(await adminService.dashboardSummary()));
  } catch (err) {
    next(err);
  }
};

export const listUsers: RequestHandler = async (req, res, next) => {
  try {
    const { query, role } = req.query;
    const page = Number(req.query.page ?? 1);
    const pageSize = Number(req.query.pageSize ?? 20);
    res.json(
      ok(
        await adminService.listUsers({
          query: typeof query === 'string' ? query : undefined,
          role: typeof role === 'string' ? (role as 'STUDENT' | 'ADMIN' | 'SUPER_ADMIN') : undefined,
          page,
          pageSize,
        }),
      ),
    );
  } catch (err) {
    next(err);
  }
};

export const setUserStatus: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(
        await adminService.setUserStatus(
          req.user!.userId,
          req.params.userId as string,
          req.body.accountStatus,
        ),
      ),
    );
  } catch (err) {
    next(err);
  }
};

export const pendingDrivers: RequestHandler = async (_req, res, next) => {
  try {
    res.json(ok(await adminService.listPendingDrivers()));
  } catch (err) {
    next(err);
  }
};

export const verifyDriver: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(
        await adminService.verifyDriver(
          req.user!.userId,
          req.params.userId as string,
          req.body.status,
        ),
      ),
    );
  } catch (err) {
    next(err);
  }
};

export const pendingVehicles: RequestHandler = async (_req, res, next) => {
  try {
    res.json(ok(await adminService.listPendingVehicles()));
  } catch (err) {
    next(err);
  }
};

export const verifyVehicle: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(
        await adminService.verifyVehicle(
          req.user!.userId,
          req.params.vehicleId as string,
          req.body.status,
        ),
      ),
    );
  } catch (err) {
    next(err);
  }
};

export const listReports: RequestHandler = async (req, res, next) => {
  try {
    const status = typeof req.query.status === 'string'
      ? (req.query.status as 'OPEN' | 'RESOLVED' | 'DISMISSED')
      : undefined;
    const page = Number(req.query.page ?? 1);
    const pageSize = Number(req.query.pageSize ?? 20);
    res.json(ok(await adminService.listReports({ status, page, pageSize })));
  } catch (err) {
    next(err);
  }
};

export const resolveReport: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(
        await adminService.resolveReport(
          req.user!.userId,
          req.params.id as string,
          req.body.status,
          req.body.adminAction,
        ),
      ),
    );
  } catch (err) {
    next(err);
  }
};