import { Router } from 'express';
import * as campusController from '../controllers/campus.controller.js';
import { validateParams } from '../middleware/validation.middleware.js';
import { idParamSchema } from '../validators/common.schema.js';

export const campusRouter = Router();

campusRouter.get('/', campusController.listCampuses);
campusRouter.get('/:id', validateParams(idParamSchema), campusController.getCampus);