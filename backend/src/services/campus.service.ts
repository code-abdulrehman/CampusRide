import { ErrorCodes } from '../common/errors/codes.js';
import { ApiError } from '../common/errors/api-error.js';
import { toCampus } from '../common/utils/serializers.js';
import { prisma } from '../config/prisma.js';

export async function listCampuses() {
  const campuses = await prisma.campus.findMany({
    where: { active: true },
    orderBy: { name: 'asc' },
  });
  return campuses.map(toCampus);
}

export async function getCampus(campusId: string) {
  const campus = await prisma.campus.findFirst({ where: { id: campusId, active: true } });
  if (!campus) throw new ApiError(404, ErrorCodes.CAMPUS_NOT_FOUND, 'Campus not found');
  return toCampus(campus);
}