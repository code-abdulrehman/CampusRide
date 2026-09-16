export interface ApiSuccess<T = unknown> {
  success: true;
  data: T;
  meta: unknown;
}

export interface ApiErrorBody {
  success: false;
  error: {
    code: string;
    message: string;
    fields: unknown;
  };
}

export function ok<T>(data: T, meta: unknown = null): ApiSuccess<T> {
  return { success: true, data, meta };
}

export function fail(code: string, message: string, fields: unknown = null): ApiErrorBody {
  return { success: false, error: { code, message, fields } };
}

export type ApiResponse<T> = ApiSuccess<T> | ApiErrorBody;