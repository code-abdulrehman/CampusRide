import { Router } from 'express';
import * as reportController from '../controllers/report.controller.js';
import { requireAuth } from '../middleware/auth.middleware.js';
import { validateBody } from '../middleware/validation.middleware.js';
import { createReportSchema } from '../validators/report.schema.js';

export const reportRouter = Router();

reportRouter.use(requireAuth);

reportRouter.get('/mine', reportController.myReports);
reportRouter.post('/', validateBody(createReportSchema), reportController.createReport);