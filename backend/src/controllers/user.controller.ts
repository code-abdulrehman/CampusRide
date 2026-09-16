import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as userService from '../services/user.service.js';

export const getMe: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await userService.getMe(req.user!.userId)));
  } catch (err) {
    next(err);
  }
};

export const updateMe: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await userService.updateMe(req.user!.userId, req.body)));
  } catch (err) {
    next(err);
  }
};

export const setAvatar: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await userService.setAvatar(req.user!.userId, req.body.avatarKey)));
  } catch (err) {
    next(err);
  }
};

export const getPublicProfile: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await userService.getPublicUser(req.params.userId as string)));
  } catch (err) {
    next(err);
  }
};

export const bootstrap: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await userService.bootstrap(req.user!.userId)));
  } catch (err) {
    next(err);
  }
};