export const APP_NAME = 'CampusRide';

export const API_PREFIX = '/api/v1';

export const BODY_SIZE_LIMIT = '256kb' as const;

export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

export const ALLOWED_AVATAR_KEYS = Array.from({ length: 20 }, (_, i) =>
  `avatar_${String(i + 1).padStart(2, '0')}`,
);

export const PASSWORD_REGEX = /^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,128}$/;