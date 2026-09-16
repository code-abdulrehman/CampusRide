import { VerificationStatus, VehicleType } from '@prisma/client';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { toVehicle } from '../common/utils/serializers.js';
import { prisma } from '../config/prisma.js';

export interface CreateVehicleInput {
  vehicleType: VehicleType;
  company: string;
  model: string;
  year: number;
  color: string;
  registrationNumber: string;
  totalSeats: number;
  passengerCapacity: number;
}

export async function listMyVehicles(userId: string) {
  const vehicles = await prisma.vehicle.findMany({
    where: { ownerId: userId, active: true },
    orderBy: { createdAt: 'desc' },
  });
  return vehicles.map(toVehicle);
}

export async function createVehicle(userId: string, input: CreateVehicleInput) {
  const registration = input.registrationNumber.trim().toUpperCase();
  const existing = await prisma.vehicle.findUnique({ where: { registrationNumber: registration } });
  if (existing) {
    throw new ApiError(409, ErrorCodes.VALIDATION, 'Vehicle registration number already exists');
  }
  const vehicle = await prisma.vehicle.create({
    data: {
      ownerId: userId,
      vehicleType: input.vehicleType,
      company: input.company.trim(),
      model: input.model.trim(),
      year: input.year,
      color: input.color.trim(),
      registrationNumber: registration,
      totalSeats: input.totalSeats,
      passengerCapacity: input.passengerCapacity,
      verificationStatus: VerificationStatus.PENDING,
    },
  });
  return toVehicle(vehicle);
}

export async function updateOwnVehicle(
  userId: string,
  vehicleId: string,
  patch: Partial<CreateVehicleInput>,
) {
  const vehicle = await prisma.vehicle.findFirst({ where: { id: vehicleId, ownerId: userId } });
  if (!vehicle) throw new ApiError(404, ErrorCodes.VEHICLE_NOT_FOUND, 'Vehicle not found');

  const data: Record<string, unknown> = {};
  if (patch.company !== undefined) data.company = patch.company.trim();
  if (patch.model !== undefined) data.model = patch.model.trim();
  if (patch.color !== undefined) data.color = patch.color.trim();
  if (patch.year !== undefined) data.year = patch.year;
  if (patch.vehicleType !== undefined) data.vehicleType = patch.vehicleType;
  if (patch.totalSeats !== undefined) data.totalSeats = patch.totalSeats;
  if (patch.passengerCapacity !== undefined) data.passengerCapacity = patch.passengerCapacity;

  const updated = await prisma.vehicle.update({
    where: { id: vehicleId },
    data: { ...data, verificationStatus: VerificationStatus.PENDING },
  });
  return toVehicle(updated);
}

export async function deactivateOwnVehicle(userId: string, vehicleId: string) {
  const vehicle = await prisma.vehicle.findFirst({ where: { id: vehicleId, ownerId: userId } });
  if (!vehicle) throw new ApiError(404, ErrorCodes.VEHICLE_NOT_FOUND, 'Vehicle not found');
  const upcoming = await prisma.ride.count({
    where: {
      vehicleId,
      driverId: userId,
      status: { in: ['OPEN', 'FULL', 'STARTED'] },
      departureAt: { gt: new Date() },
    },
  });
  if (upcoming > 0) {
    throw new ApiError(409, ErrorCodes.RIDE_INVALID_STATE, 'Vehicle has upcoming rides and cannot be removed');
  }
  await prisma.vehicle.update({
    where: { id: vehicleId },
    data: { active: false },
  });
  return { id: vehicleId, active: false };
}