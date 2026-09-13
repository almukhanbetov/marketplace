# Mobile Auth Compatibility

**Status: Option B implemented in Stage F2.** The additive backend
extension below is live; the Next.js web flow is byte-for-byte unchanged
(verified — see `flutter/docs/../` report §25 and the backend
`auth_mobile_test.go` suite).

**Original question (Stage F1 §49):** does the existing Stage-9 auth API
work for a native Flutter app?

**Answer: yes for login / me / RBAC / access-token use as-is; the refresh
+ logout endpoints needed a small backward-compatible backend extension,
now shipped.**

---

## What the web does

| Step | Transport |
|---|---|
| `POST /auth/login` | access token in **response body**; refresh token in `Set-Cookie: refresh_token=…; HttpOnly; SameSite=Lax; Path=/api/v1/auth` |
| authorized calls | `Authorization: Bearer <access>` header |
| `POST /auth/refresh` | browser auto-sends the cookie; handler reads `c.Cookie("refresh_token")`; responds with a new access token + a rotated cookie |
| `POST /auth/logout` | same cookie-only read |

`HttpOnly` / `SameSite` / `Path` are **browser** enforcement concepts.
They protect the web app from XSS/CSRF. They mean nothing to Dio.

## What a native client can and cannot do

| Concern | Native reality |
|---|---|
| Read `Set-Cookie` from the login response | ✅ Dio exposes `response.headers['set-cookie']` |
| Store the refresh token securely | ✅ `flutter_secure_storage` → Keychain / EncryptedSharedPreferences (the native equivalent of "not JS-readable") |
| Send it back to `/auth/refresh` | ⚠️ only by setting a `Cookie: refresh_token=<value>` **request header** by hand (or a `cookie_jar`), i.e. pretending to be a browser |
| Everything else (login, `/auth/me`, `/me/*`, `/seller/*`, bearer, RBAC, rotation, reuse-detection, deactivation-takes-effect) | ✅ works unchanged |

So the **only** friction is the refresh/logout transport channel.

## Option A — zero backend change (fallback)

`ApiClient` on login/refresh parses `refresh_token=<v>` out of the
`set-cookie` header, stores `<v>` in `SecureStore`, and on
refresh/logout sends `options.headers['Cookie'] = 'refresh_token=$v'`.
`c.Cookie()` in Gin just parses the `Cookie` request header, so this works
today.

- ✅ no backend change, web untouched
- ➖ the client is coupled to a browser-transport detail; parsing
  `Set-Cookie` is fiddly (attributes, quoting); semantically odd for a
  REST client

## Option B — the extension that shipped (Stage F2)

All in `internal/handlers/auth_handler.go` (`clientIsMobile`,
`mobileAuthData`, `mobileRefreshTokenBody`). **No new route, no migration,
no change to `auth_sessions`, no service/repository change** —
rotation / revocation / reuse-detection / user-active checks run through
the exact same `AuthService` calls.

Transport selector: `X-Client: nova-mobile` (added centrally by
`ApiClient`).

| Endpoint | Web (no marker) — **unchanged** | Native (`X-Client: nova-mobile`) |
|---|---|---|
| `POST /auth/login` | `{user, access_token, expires_at}` + `Set-Cookie: refresh_token` (HttpOnly) | `{access_token, access_expires_at, refresh_token, refresh_expires_at, user}` — **no cookie** |
| `POST /auth/register` | `{...user}` (201, no tokens) | same mobile bundle as login (201) — the server does the "auto-login after signup" the web frontend used to do client-side |
| `POST /auth/refresh` | reads cookie, rotates cookie, body `{access_token, expires_at}` | reads `{"refresh_token": "..."}` from the body, returns the rotated pair in the body, **never touches the cookie** |
| `POST /auth/logout` | revokes the cookie session, clears the cookie | revokes the session for the body `{"refresh_token": "..."}`, no cookie |
| `POST /auth/logout-all`, `GET /auth/me` | access-token auth — already worked for native, untouched | same |

The `user` object for native login/register is the fuller `UserDetail`
(carries `seller_id`), so the app has role + seller identity without a
second `/auth/me` call.

### Verified

- `internal/handlers/auth_mobile_test.go`: web login/register never emit
  `refresh_token` in the body; mobile does; mobile refresh rotates +
  reuse of the pre-rotation token → 401 (whole-chain revoke); mobile
  logout revokes; inactive account still blocked for mobile.
- curl E2E (both transports) + a Flutter-side integration test
  (`test/backend_integration_test.dart`) driving `AuthRepositoryImpl`
  against the live backend.

### Spoofing (Stage F2 §49)

`X-Client` is **not** a permission or identity proof — a browser could
send it, and doing so would only opt *that request* into body-transport
of the refresh token (a strictly worse XSS position for a browser, which
is exactly why the web client never sends it). Security is unchanged: the
token is still 256-bit random, still stored only as a SHA-256 hash, still
rotated, still reuse-protected, and every request is still validated the
same way regardless of transport.

## Non-negotiables (both options)

- refresh token: Keychain / EncryptedSharedPreferences **only** — never
  `SharedPreferences`, never a file, never a provider that gets logged
- access token: in-memory only (`TokenStore._accessToken`)
- never log `Authorization`, `Cookie`, `X-Refresh-Token`, `refresh_token`,
  or passwords (the F1 log interceptor prints method + URL + status only)
- one refresh attempt per 401, then one retry, then force-logout — no loop
  (`ApiClient` + `TokenRefresher`)
- **do not change the web auth contract**
