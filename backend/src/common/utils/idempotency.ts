interface StoredResponse {
  statusCode: number;
  body: unknown;
}

const store = new Map<string, { response: StoredResponse; expiresAt: number }>();
const TTL_MS = 60 * 60 * 1000;

export function getStoredResponse(key: string): StoredResponse | null {
  const entry = store.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    store.delete(key);
    return null;
  }
  return entry.response;
}

export function storeIdempotentResponse(key: string, statusCode: number, body: unknown): void {
  store.set(key, { response: { statusCode, body }, expiresAt: Date.now() + TTL_MS });
}