import dotenv from 'dotenv';

dotenv.config();

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL =
  process.env.TEST_DATABASE_URL ??
  'postgresql://dycoders@localhost:5432/campusride_test?schema=public';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-0123456789abcdefghijklmnopqrstuv';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-0123456789abcdefghijklmnopqrstuv';