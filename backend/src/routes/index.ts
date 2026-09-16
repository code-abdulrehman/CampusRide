import { Router } from 'express';
import { health, ready } from '../controllers/health.controller.js';
import { authRouter } from './auth.routes.js';
import { userRouter } from './user.routes.js';
import { campusRouter } from './campus.routes.js';
import { vehicleRouter } from './vehicle.routes.js';
import { rideRouter } from './ride.routes.js';
import { rideRequestRouter } from './ride-request.routes.js';
import { bookingRouter } from './booking.routes.js';
import { ratingRouter } from './rating.routes.js';
import { reportRouter } from './report.routes.js';
import { notificationRouter } from './notification.routes.js';
import { adminRouter } from './admin.routes.js';

export const apiRouter = Router({ mergeParams: true });

apiRouter.get('/health', health);
apiRouter.get('/ready', ready);

apiRouter.use('/auth', authRouter);
apiRouter.use('/users', userRouter);
apiRouter.use('/campuses', campusRouter);
apiRouter.use('/vehicles', vehicleRouter);
apiRouter.use('/rides', rideRouter);
apiRouter.use(bookingRouter);
apiRouter.use('/ride-requests', rideRequestRouter);
apiRouter.use(ratingRouter);
apiRouter.use('/reports', reportRouter);
apiRouter.use('/notifications', notificationRouter);
apiRouter.use('/admin', adminRouter);