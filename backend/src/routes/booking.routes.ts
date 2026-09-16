import { Router } from 'express';
import * as bookingController from '../controllers/booking.controller.js';
import { requireAuth } from '../middleware/auth.middleware.js';
import { validateBody, validateParams } from '../middleware/validation.middleware.js';
import { idParamSchema, rideIdParamSchema } from '../validators/common.schema.js';
import { checkinSchema, createBookingSchema } from '../validators/booking.schema.js';

export const bookingRouter = Router();

bookingRouter.get('/bookings/mine', requireAuth, bookingController.myBookings);
bookingRouter.post(
  '/rides/:rideId/bookings',
  requireAuth,
  validateParams(rideIdParamSchema),
  validateBody(createBookingSchema),
  bookingController.createBooking,
);
bookingRouter.get(
  '/rides/:rideId/bookings',
  requireAuth,
  validateParams(rideIdParamSchema),
  bookingController.listRideBookings,
);
bookingRouter.get(
  '/bookings/:id',
  requireAuth,
  validateParams(idParamSchema),
  bookingController.getBooking,
);
bookingRouter.post(
  '/bookings/:id/accept',
  requireAuth,
  validateParams(idParamSchema),
  bookingController.acceptBooking,
);
bookingRouter.post(
  '/bookings/:id/reject',
  requireAuth,
  validateParams(idParamSchema),
  bookingController.rejectBooking,
);
bookingRouter.post(
  '/bookings/:id/cancel',
  requireAuth,
  validateParams(idParamSchema),
  bookingController.cancelBooking,
);
bookingRouter.post(
  '/bookings/:id/checkin',
  requireAuth,
  validateParams(idParamSchema),
  validateBody(checkinSchema),
  bookingController.checkinBooking,
);
bookingRouter.post(
  '/bookings/:id/no-show',
  requireAuth,
  validateParams(idParamSchema),
  bookingController.noShowBooking,
);