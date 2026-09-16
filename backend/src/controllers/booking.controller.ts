import type { RequestHandler } from 'express';
import { ok } from '../common/response/response.js';
import * as bookingService from '../services/booking.service.js';

export const createBooking: RequestHandler = async (req, res, next) => {
  try {
    const result = await bookingService.requestBooking(
      req.user!.userId,
      req.params.rideId as string,
      req.body.seats,
    );
    res.status(201).json(ok(result));
  } catch (err) {
    next(err);
  }
};

export const myBookings: RequestHandler = async (req, res, next) => {
  try {
    res.json(ok(await bookingService.myBookings(req.user!.userId)));
  } catch (err) {
    next(err);
  }
};

export const getBooking: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await bookingService.getBooking(req.user!.userId, req.params.id as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const listRideBookings: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await bookingService.listRideBookings(req.user!.userId, req.params.rideId as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const acceptBooking: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await bookingService.acceptBooking(req.user!.userId, req.params.id as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const rejectBooking: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await bookingService.rejectBooking(req.user!.userId, req.params.id as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const cancelBooking: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await bookingService.cancelBooking(req.user!.userId, req.params.id as string)),
    );
  } catch (err) {
    next(err);
  }
};

export const checkinBooking: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(
        await bookingService.checkinBooking(
          req.user!.userId,
          req.params.id as string,
          req.body.checkinPin,
        ),
      ),
    );
  } catch (err) {
    next(err);
  }
};

export const noShowBooking: RequestHandler = async (req, res, next) => {
  try {
    res.json(
      ok(await bookingService.noShowBooking(req.user!.userId, req.params.id as string)),
    );
  } catch (err) {
    next(err);
  }
};