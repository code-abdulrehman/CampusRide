import { Router } from 'express';
import * as userController from '../controllers/user.controller.js';
import { requireAuth } from '../middleware/auth.middleware.js';
import { validateBody, validateParams } from '../middleware/validation.middleware.js';
import { userIdParamSchema } from '../validators/common.schema.js';
import { setAvatarSchema, updateMeSchema } from '../validators/user.schema.js';

export const userRouter = Router();

userRouter.get('/bootstrap', requireAuth, userController.bootstrap);
userRouter.get('/me', requireAuth, userController.getMe);
userRouter.patch('/me', requireAuth, validateBody(updateMeSchema), userController.updateMe);
userRouter.patch('/me/avatar', requireAuth, validateBody(setAvatarSchema), userController.setAvatar);
userRouter.get(
  '/:userId/public',
  validateParams(userIdParamSchema),
  userController.getPublicProfile,
);