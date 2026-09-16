import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { toCampus, toPublicUser, toRide } from '../common/utils/serializers.js';
import { ALLOWED_AVATAR_KEYS } from '../config/constants.js';
import { prisma } from '../config/prisma.js';
import { unreadNotificationsCount } from './notification.service.js';

export async function getMe(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'User not found');
  return toPublicUser(user);
}

export async function updateMe(
  userId: string,
  patch: { fullName?: string; mainCampusId?: string },
) {
  const data: { fullName?: string; mainCampusId?: string | null } = {};
  if (patch.fullName !== undefined) data.fullName = patch.fullName.trim();
  if (patch.mainCampusId !== undefined) {
    if (patch.mainCampusId !== null) {
      const campus = await prisma.campus.findUnique({
        where: { id: patch.mainCampusId },
      });
      if (!campus) throw new ApiError(400, ErrorCodes.CAMPUS_NOT_FOUND, 'Campus not found');
    }
    data.mainCampusId = patch.mainCampusId;
  }
  if (Object.keys(data).length === 0) {
    return getMe(userId);
  }
  const user = await prisma.user.update({ where: { id: userId }, data });
  return toPublicUser(user);
}

export async function setAvatar(userId: string, avatarKey: string) {
  if (!ALLOWED_AVATAR_KEYS.includes(avatarKey)) {
    throw new ApiError(400, ErrorCodes.VALIDATION, 'avatarKey must be one of: ' + ALLOWED_AVATAR_KEYS.join(', '));
  }
  const user = await prisma.user.update({ where: { id: userId }, data: { avatarKey } });
  return toPublicUser(user);
}

export async function getPublicUser(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new ApiError(404, ErrorCodes.NOT_FOUND, 'User not found');
  return toPublicUser(user);
}

export async function bootstrap(userId: string) {
  const user = await getMe(userId);

  const [campuses, asDriver, asPassengerBookings, unreadCount] = await Promise.all([
    prisma.campus.findMany({ where: { active: true }, orderBy: { name: 'asc' } }),
    prisma.ride.findMany({
      where: {
        driverId: userId,
        status: { in: ['OPEN', 'FULL', 'STARTED'] },
        departureAt: { gte: new Date(Date.now() - 3 * 3_600_000) },
      },
      orderBy: { departureAt: 'asc' },
      take: 10,
    }),
    prisma.booking.findMany({
      where: {
        passengerId: userId,
        status: { in: ['ACCEPTED', 'CHECKED_IN', 'RIDE_STARTED'] },
      },
      include: { ride: { include: { driver: true } } },
      orderBy: { ride: { departureAt: 'asc' } },
      take: 10,
    }),
    unreadNotificationsCount(userId),
  ]);

  const upcomingRides = [
    ...asDriver.map((ride) => ({ role: 'driver' as const, ride: toRide(ride) })),
    ...asPassengerBookings
      .filter((b) => b.ride.departureAt.getTime() >= Date.now() - 3_600_000)
      .map((b) => ({
        role: 'passenger' as const,
        ride: toRide(b.ride),
        bookingStatus: b.status,
      })),
  ].sort((a, b) => a.ride.departureAt.getTime() - b.ride.departureAt.getTime());

  const activeRide =
    upcomingRides.find((r) => r.ride.status === 'STARTED') ?? null;

  return {
    user,
    campuses: campuses.map(toCampus),
    upcomingRides,
    activeRide,
    unreadCount,
  };
}