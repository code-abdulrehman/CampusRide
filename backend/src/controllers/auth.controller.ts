import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as authService from '../services/auth.service.js';

export const register: RequestHandler = async (req, res, next) => {
  try {
    const result = await authService.register(req.body);
    res.status(201).json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const login: RequestHandler = async (req, res, next) => {
  try {
    const result = await authService.login(req.body);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const refresh: RequestHandler = async (req, res, next) => {
  try {
    const result = await authService.refresh(req.body.refreshToken);
    res.json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const logout: RequestHandler = async (req, res, next) => {
  try {
    await authService.logout(req.body.refreshToken);
    res.json(ok(null));
  } catch (err) {
    next(err);
  }
};