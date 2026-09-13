# NOVA Marketplace — Mobile (Flutter)

Native iOS/Android client for the existing **NOVA Marketplace** platform
(`nova.kz`). It talks **only** to the existing Go REST API
(`backend/`, `/api/v1`) — there is no separate mobile backend, and no
business logic (pricing, commissions, balances, order totals, inventory
authority) is re-implemented here. The Go backend stays the single source
of truth.

| | |
|---|---|
| Flutter | 3.44.0 (Dart 3.12) |
| State | Riverpod 3 (`NotifierProvider`, `Provider`) |
| Routing | go_router 18 (`StatefulShellRoute` bottom-nav shell) |
| HTTP | Dio 5 (one shared `ApiClient` with auth + refresh-retry interceptor) |
| Secure storage | `flutter_secure_storage` 11 (refresh token only) |
| Prefs | `shared_preferences` (theme + language only — never secrets) |
| Package id | `kz.nova.marketplace` (Android `applicationId`) |

## Project status

**Stage F7B — real Android device verification — complete.** Ran the app
on the `Pixel_6a_API_33` emulator (Android 13) against
`http://10.0.2.2:8081/api/v1` and walked the full customer flow (login →
home → catalog → product → cart → checkout → real `POST /me/orders 201`
→ order success → orders), settings (theme + language), a seller login →
dashboard, and logout — all against the live backend, in both themes and
at OS font size 1.3. Two device-only bugs were found and fixed: the
product sticky bar truncated "Купить сейчас" on a narrow screen (now a
price line above two full-width CTAs), and the home product rails clipped
the price at a large font scale (the rail now grows with
`MediaQuery.textScaler`). No Flutter exceptions or layout overflows in
logcat. iOS/macOS (F7C) still needs a Mac. See `docs/STAGE_PLAN.md`.

Earlier: **F7A — UI / UX polish.** Presentation-only, no new
features and no backend changes. A real design-system layer landed:
`core/theme/app_dimens.dart` holds the spacing scale (`NovaSpace`, 4→32),
the four corner radii (`NovaRadii`), motion durations (`NovaDurations`,
150–300ms) and `NovaShadows` (a whisper-soft lift in light, nothing in
dark). `app_theme.dart` now owns a named type hierarchy
(display→labelSmall), modern page transitions, and dialog/list-tile/
tooltip themes; `app.dart` caps the OS text scale at 1.4. New shared
widgets — `NovaStateView` (behind the unchanged `EmptyView`/`ErrorView`),
`NovaSkeleton`/`NovaSkeletonList` (shimmer, replacing every flat-grey
placeholder), `nova_feedback.dart` (`NovaSnackbar` + `novaConfirm`),
`NovaSectionLabel`, `NovaStickyBar` (one elevated bottom bar with a single
`SafeArea` for product/cart/checkout). Every screen was re-spaced on the
tokens; cards gained the soft shadow and a press ripple. Light stays
exactly `#FFFFFF`, dark stays graphite. `test/f7a_polish_test.dart` (24
tests) covers the tokens, theme invariants, and state-view/card
resilience at textScale 1.0–1.4 in both themes. **F7B** is the on-device
pass — see `docs/STAGE_PLAN.md`.

Earlier: **F6E — Final seller regression + polish.** No new seller
features. `test/f6e_seller_regression_test.dart` (25 tests) walks the whole
console as one flow (dashboard → offers → inventory → orders → order
detail → finance → payouts) with no exceptions and the light scaffold at
`#FFFFFF`, checks every F6 seller string key resolves, covers 18
role/routing cases across all 6 seller routes, a `403` dashboard →
"аккаунт продавца недоступен" + graceful exit, a seller with no linked
`seller_id`, logout-clears / re-login-reloads all four seller controllers,
and a single-`401` → refresh → retry with no loop. The one polish fix:
all six seller controllers now also reset on `AuthStatus.unauthenticated`
so logout drops seller data from memory (the F4 customer pattern).
Integration test: a deactivated seller is `403`/`401` on every
`/seller/*` endpoint and reactivation restores access. The seller console
(F6A–F6E) is done; **F7** is the production-polish pass — see
`docs/STAGE_PLAN.md`.

Earlier: **F6D — Seller finance + payouts** (`GET /seller/finance`,
`GET|POST /seller/payouts`; only-available-is-withdrawable, one UUID
`Idempotency-Key` per attempt, no bank fields, `INSUFFICIENT_AVAILABLE_BALANCE`
as a localized banner). **F6C — Seller orders** (read-only, seller-scoped, multi-seller
isolation proven). **F6B — Seller offers + inventory**. **F6A — Seller
foundation + dashboard**. **F5 — Checkout + Orders**. **F4 — Customer state**.

Deps added in F3: `cached_network_image` (no new deps F4–F6B). Riverpod's
automatic retry is disabled app-wide (`ProviderScope(retry: (_,_) =>
null)`) so a failed fetch surfaces an `ErrorView` with a manual Retry,
not a silent loop.

### Auth (F2)

- **Access token** — in memory only (`TokenStore`), lost on restart.
- **Refresh token** — `flutter_secure_storage` only (Keychain / Keystore),
  keys in `core/storage/storage_keys.dart`. Never `SharedPreferences`.
- **Transport** — `ApiClient` sends `X-Client: nova-mobile`; the backend
  then returns the refresh token in the login/register/refresh JSON body
  (native pattern) instead of an HttpOnly cookie (web pattern). The web
  flow is untouched. See `docs/AUTH_COMPAT.md`.
- **Silent restore** — on launch, a stored refresh token is exchanged
  behind a splash; a transient network failure keeps the token and shows
  a retry, an invalid session clears it.
- **401 handling** — the Dio interceptor does exactly one single-flight
  refresh + one retry, then forces logout. Never recurses on `/auth/*`
  transport endpoints.
- **Guards** — `kEnableRouteGuards = true`. Protected routes → login (with
  return-to); customer on `/seller/*` → "sellers only"; admin → a
  web-only notice (no mobile admin UI).

## Running it

The API base URL is **never hardcoded** — pass it with `--dart-define`:

```bash
# Android emulator → host machine backend on :8081
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1

# iOS simulator → host machine
flutter run --dart-define=API_BASE_URL=http://localhost:8081/api/v1

# Physical device → your machine's LAN IP (and add it to
# android/app/src/main/res/xml/network_security_config.xml, or use HTTPS)
flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8081/api/v1

# Production
flutter build apk --release --dart-define=API_BASE_URL=https://api.nova.kz/api/v1 --dart-define=APP_ENV=production
```

Default (no define): `http://10.0.2.2:8081/api/v1` (emulator dev).

Local dev accounts (from `backend/seeds`, password `NovaDev2026`):
`admin@nova.kz`, `techstore@nova.kz` (seller), `aigerim@example.com` (customer).

## Quality gates

```bash
flutter pub get
dart format .
flutter analyze          # 0 issues
flutter test             # 20 tests
flutter build apk --debug
```

## Layout

```
lib/
  app/            NovaApp (MaterialApp.router)
  core/
    env/          --dart-define config
    api/          ApiClient (Dio), TokenRefresher contract, providers
    auth/         AuthController, AuthRepository (skeleton), TokenStore
    errors/       ApiException + backend-code mapping
    storage/      SecureStore (Keychain), PreferencesStore
    theme/        NovaColors tokens, AppTheme, ThemeController
    localization/ AppLocale, AppStrings, per-language string maps
    router/       GoRouter config, route constants, guards (F2)
    utils/        Money formatting
  shared/
    widgets/      AppShell, Loading/Empty/Error/Placeholder views
    models/       Paginated<T>
    constants/
  features/
    <area>/data/          repository + models  (favorites, cart, addresses in F4)
    <area>/application/   Riverpod controllers (FavoritesController, CartController, AddressesController)
    <area>/presentation/  screens + widgets
docs/             AUDIT.md, API_MAP.md, AUTH_COMPAT.md, ANDROID_IOS.md, STAGE_PLAN.md
```

## Docs

- **`docs/AUDIT.md`** — audit of the existing backend + web frontend.
- **`docs/API_MAP.md`** — every endpoint → method → auth → role → Flutter target.
- **`docs/AUTH_COMPAT.md`** — how a native client participates in the
  Stage-9 access-JWT + refresh-cookie flow, and the minimal
  backward-compatible backend change proposed for F2.
- **`docs/ANDROID_IOS.md`** — API connectivity per platform/target.
- **`docs/STAGE_PLAN.md`** — F1–F7 breakdown.
