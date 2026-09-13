# API connectivity — Android / iOS

`API_BASE_URL` is a compile-time `--dart-define` (see `core/env/app_env.dart`).
Never hardcoded. Default when omitted: `http://10.0.2.2:8081/api/v1`.

> The local backend currently runs on **:8081** (8080 is taken by another
> project on this machine) with Postgres on **:5434**. Adjust the port in
> the URLs below to match your `backend/.env` / run config.

## Android

| Target | `API_BASE_URL` |
|---|---|
| Emulator → host backend | `http://10.0.2.2:8081/api/v1` (`10.0.2.2` = host loopback) |
| Physical device, same Wi-Fi, HTTP backend | `http://<your-computer-LAN-IP>:8081/api/v1` **and** add that IP to `android/app/src/main/res/xml/network_security_config.xml` |
| Physical device, HTTPS backend | `https://api.nova.kz/api/v1` — no manifest change needed |

Cleartext HTTP is **denied by default** (`network_security_config.xml`,
`base-config cleartextTrafficPermitted="false"`); only `10.0.2.2`,
`localhost`, `127.0.0.1` are excepted for dev. `INTERNET` permission is in
the main manifest.

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1
flutter build apk --debug
flutter build apk --release --dart-define=API_BASE_URL=https://api.nova.kz/api/v1 --dart-define=APP_ENV=production
```

## iOS

| Target | `API_BASE_URL` |
|---|---|
| Simulator → host backend | `http://localhost:8081/api/v1` |
| Physical iPhone, same Wi-Fi, HTTP backend | `http://<your-computer-LAN-IP>:8081/api/v1` **and** add that host to the `NSExceptionDomains` dict in `ios/Runner/Info.plist` |
| Physical iPhone, HTTPS backend | `https://api.nova.kz/api/v1` |

`Info.plist` sets `NSAllowsArbitraryLoads=false` with a `localhost`
insecure-HTTP exception for the simulator. **Not built/tested in this
environment** (no macOS/Xcode) — the config is in place; verify on a Mac.

## CORS

Irrelevant to native apps — CORS is a browser mechanism. The backend's
`FRONTEND_URL` / CORS config only affects the Next.js web client. A native
Dio request carries no `Origin` and is not subject to a preflight.

## The `X-Client: nova-mobile` header

`ApiClient` adds it to every request. Today the backend ignores it; Stage
F2's proposed auth extension keys off it to return the refresh token in
the body for native clients only (see `AUTH_COMPAT.md`).
