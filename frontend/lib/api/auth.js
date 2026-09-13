import { apiFetch } from "@/lib/api/client";
import { setAccessToken, clearAccessToken } from "@/lib/api/authToken";

export async function register({ email, phone, fullName, password }) {
  const res = await apiFetch("/auth/register", {
    method: "POST",
    body: JSON.stringify({ email, phone, full_name: fullName, password }),
  });
  return res.data;
}

/** Stores the returned access token in memory (never localStorage) —
 * the refresh token itself is an HttpOnly cookie this code never sees
 * (Stage 9 §36/§79). */
export async function login({ email, phone, password }) {
  const res = await apiFetch("/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, phone, password }),
  });
  setAccessToken(res.data?.access_token);
  return res.data?.user;
}

/** Silent session recovery on page load: the HttpOnly refresh cookie (if
 * any) is enough to mint a fresh access token with no visible login step —
 * this is what makes a session "survive a refresh" (Stage 9 §77) without
 * ever touching localStorage. Returns null (never throws) if there is no
 * valid session. */
export async function trySilentRefresh() {
  try {
    const res = await apiFetch("/auth/refresh", { method: "POST" });
    setAccessToken(res.data?.access_token);
    return res.data?.access_token || null;
  } catch {
    clearAccessToken();
    return null;
  }
}

export async function getMe() {
  const res = await apiFetch("/auth/me");
  return res.data;
}

export async function logout() {
  try {
    await apiFetch("/auth/logout", { method: "POST" });
  } finally {
    clearAccessToken();
  }
}

export async function logoutAll() {
  try {
    await apiFetch("/auth/logout-all", { method: "POST" });
  } finally {
    clearAccessToken();
  }
}
