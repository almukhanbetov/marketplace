/**
 * The access token lives ONLY here — a plain module-scoped variable, i.e.
 * JS heap memory for this tab, never localStorage/sessionStorage/a cookie
 * (Stage 9 §3/§36/§79). It is lost on a hard page reload by design; the
 * refresh flow (HttpOnly cookie, invisible to this module) is what
 * silently re-establishes it on the next load — see AuthContext.
 */
let accessToken = null;

export function getAccessToken() {
  return accessToken;
}

export function setAccessToken(token) {
  accessToken = token || null;
}

export function clearAccessToken() {
  accessToken = null;
}
