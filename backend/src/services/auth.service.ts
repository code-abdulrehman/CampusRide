import { Role, VerificationStatus } from '@prisma/client';
import argon2 from 'argon2';
import { ApiError } from '../common/errors/api-error.js';
import { ErrorCodes } from '../common/errors/codes.js';
import { toPublicUser } from '../common/utils/serializers.js';
import { prisma } from '../config/prisma.js';
import { env } from '../config/env.js';
import { generateRefreshToken, hashRefreshToken } from '../common/utils/token.js';
import { signAccessToken } from './token.service.js';

export interface RegisterInput {
  email: string;
  fullName: string;
  password: string;
  studentId?: string;
  mainCampusId?: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

async function issueTokenPair(userId: string, role: Role): Promise<TokenPair> {
  const refreshToken = generateRefreshToken();
  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash: hashRefreshToken(refreshToken),
      expiresAt: new Date(Date.now() + env.JWT_REFRESH_TTL_DAYS * 86_400_000),
    },
  });
  return {
    accessToken: signAccessToken(userId, role),
    refreshToken,
  };
}

export async function register(input: RegisterInput) {
  const email = input.email.trim().toLowerCase();
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw new ApiError(409, ErrorCodes.EMAIL_TAKEN, 'Email is already registered');
  }
  if (input.studentId) {
    const existingStudent = await prisma.user.findUnique({
      where: { studentId: input.studentId },
    });
    if (existingStudent) {
      throw new ApiError(409, ErrorCodes.EMAIL_TAKEN, 'Student ID is already registered');
    }
  }
  if (input.mainCampusId) {
    const campus = await prisma.campus.findUnique({ where: { id: input.mainCampusId } });
    if (!campus) throw new ApiError(400, ErrorCodes.CAMPUS_NOT_FOUND, 'Campus not found');
  }

  const passwordHash = await argon2.hash(input.password, { type: argon2.argon2id });
  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      fullName: input.fullName.trim(),
      studentId: input.studentId ?? null,
      mainCampusId: input.mainCampusId ?? null,
      role: Role.STUDENT,
      studentVerified: VerificationStatus.VERIFIED,
      driverVerified: VerificationStatus.PENDING,
    },
  });

  const tokens = await issueTokenPair(user.id, user.role);
  return { user: toPublicUser(user), tokens };
}

export async function login(input: LoginInput) {
  const email = input.email.trim().toLowerCase();
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    throw new ApiError(401, ErrorCodes.AUTH_INVALID_CREDENTIALS, 'Invalid email or password');
  }
  const valid = await argon2.verify(user.passwordHash, input.password);
  if (!valid) {
    throw new ApiError(401, ErrorCodes.AUTH_INVALID_CREDENTIALS, 'Invalid email or password');
  }
  if (user.accountStatus === 'SUSPENDED') {
    throw new ApiError(403, ErrorCodes.ACCOUNT_SUSPENDED, 'Account is suspended');
  }
  const tokens = await issueTokenPair(user.id, user.role);
  return { user: toPublicUser(user), tokens };
}

export async function refresh(refreshToken: string) {
  if (!refreshToken) {
    throw new ApiError(401, ErrorCodes.AUTH_TOKEN_INVALID, 'Refresh token required');
  }
  const tokenHash = hashRefreshToken(refreshToken);
  const stored = await prisma.refreshToken.findFirst({ where: { tokenHash } });
  if (!stored || stored.revokedAt !== null || stored.expiresAt < new Date()) {
    throw new ApiError(401, ErrorCodes.AUTH_REFRESH_REVOKED, 'Refresh token is invalid or expired');
  }
  const user = await prisma.user.findUnique({ where: { id: stored.userId } });
  if (!user) {
    throw new ApiError(401, ErrorCodes.UNAUTHORIZED, 'User no longer exists');
  }
  if (user.accountStatus === 'SUSPENDED') {
    throw new ApiError(403, ErrorCodes.ACCOUNT_SUSPENDED, 'Account is suspended');
  }

  await prisma.refreshToken.update({
    where: { id: stored.id },
    data: { revokedAt: new Date() },
  });

  const tokens = await issueTokenPair(user.id, user.role);
  return { user: toPublicUser(user), tokens };
}

export async function logout(refreshToken: string): Promise<void> {
  if (!refreshToken) return;
  const tokenHash = hashRefreshToken(refreshToken);
  const stored = await prisma.refreshToken.findFirst({ where: { tokenHash } });
  if (stored && stored.revokedAt === null) {
    await prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });
  }
}