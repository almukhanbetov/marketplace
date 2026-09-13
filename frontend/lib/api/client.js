import { getAccessToken, setAccessToken, clearAccessToken } from "@/lib/api/authToken";

const API_URL = (process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080/api/v1").replace(/\/+$/, "");

export class ApiError extends Error {
  constructor(message, { status, code } = {}) {
    super(message);
    this.name = "ApiError";
    this.status = status ?? 0;
    this.code = code || "UNKNOWN_ERROR";
  }
}

// Fired whenever the client gives up on the current session (a refresh
// attempt failed) — AuthContext subscribes to clear its user state and
// prompt a re-login, without every API file needing its own 401 handling
// (Stage 9 §38/§39).
const sessionListeners = new Set();
export function onSessionExpired(fn) {
  sessionListeners.add(fn);
  return () => sessionListeners.delete(fn);
}
function notifySessionExpired() {
  clearAccessToken();
  sessionListeners.forEach((fn) => fn());
}

// Only one /auth/refresh in flight at a time — concurrent 401s from
// several parallel requests share the same attempt instead of each
// starting their own (Stage 9 §39: avoid pile-ups, not just infinite loops).
let refreshPromise = null;
async function refreshAccessToken() {
  if (!refreshPromise) {
    refreshPromise = rawFetch("/auth/refresh", { method: "POST" })
      .then((body) => {
        setAccessToken(body?.data?.access_token || null);
        return body?.data?.access_token || null;
      })
      .catch(() => {
        notifySessionExpired();
        return null;
      })
      .finally(() => {
        refreshPromise = null;
      });
  }
  return refreshPromise;
}

/** Lower-level fetch used internally (by apiFetch and the refresh call
 * above) — always sends the refresh cookie (credentials: "include") and
 * the in-memory access token if present, never retries on 401 itself. */
async function rawFetch(path, { params, headers, ...options } = {}) {
  const url = new URL(API_URL + path);
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value === undefined || value === null || value === "") continue;
      url.searchParams.set(key, String(value));
    }
  }

  const token = getAccessToken();
  const finalHeaders = { Accept: "application/json", "Content-Type": "application/json", ...(headers || {}) };
  if (token) finalHeaders.Authorization = `Bearer ${token}`;

  let res;
  try {
    res = await fetch(url.toString(), {
      cache: "no-store",
      credentials: "include",
      ...options,
      headers: finalHeaders,
    });
  } catch {
    throw new ApiError("Network error while contacting the API", { status: 0 });
  }

  let body = null;
  try {
    body = await res.json();
  } catch {
    // No/invalid JSON body — fall through to status-based handling below.
  }

  if (!res.ok) {
    throw new ApiError(body?.error?.message || `Request failed with status ${res.status}`, {
      status: res.status,
      code: body?.error?.code,
    });
  }

  return body ?? {};
}

/**
 * Centralized fetch client for the Go REST API. Unwraps the {data} /
 * {data,meta} / {error:{code,message}} envelope, attaches the in-memory
 * access token, and — for anything other than the /auth/* endpoints
 * themselves — attempts exactly one silent refresh-and-retry on a 401
 * before giving up and notifying AuthContext (Stage 9 §38/§39: never an
 * infinite refresh loop, never more than one retry).
 */
export async function apiFetch(path, options = {}) {
  try {
    return await rawFetch(path, options);
  } catch (err) {
    const isAuthEndpoint = path.startsWith("/auth/");
    if (err instanceof ApiError && err.status === 401 && !isAuthEndpoint) {
      const newToken = await refreshAccessToken();
      if (newToken) {
        return rawFetch(path, options);
      }
    }
    throw err;
  }
}
