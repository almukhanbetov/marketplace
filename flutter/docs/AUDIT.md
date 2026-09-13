# NOVA Marketplace — Audit for the Flutter Client

Audit of `backend/` and `frontend/` as they stand, to ground the mobile
client design. Nothing here changes existing code.

---

## 1. Backend architecture

**Stack:** Go 1.25 · Gin · pgx/v5 + pgxpool · PostgreSQL 17 · Goose
migrations (23 applied, latest `00023_auth.sql`). No ORM. No Redis/Kafka.

**Layering** (strict, one direction):

```
cmd/api/main.go          wires everything, starts HTTP
  └ internal/routes      the ONLY place the full URL map lives (router.go)
      └ internal/handlers Gin handlers: parse request, call service, write envelope
          └ internal/services  ALL business rules + validation (never sees gin.Context)
              └ internal/repositories  SQL only (pgx), returns models.*
                  └ PostgreSQL
internal/models      data-only read/write structs (no SQL, no HTTP)
internal/middleware  RequestID, Recovery, Logger, CORS, RequireAuth, RequireRole, RateLimit
internal/auth        password (bcrypt), jwt (HS256), refresh token, identity, ratelimit
internal/response    the { data } / { data, meta } / { error:{code,message} } envelope
internal/money       decimal-string money (NUMERIC(14,2) → ::text, never float64)
```

**Response envelope** (every endpoint):

```jsonc
{ "data": <object> }                                  // single
{ "data": [ ... ], "meta": { "limit", "offset", "total" } }  // list
{ "error": { "code": "SNAKE_UPPER", "message": "safe text" } }  // error
```
Errors never leak SQL/stack/paths. HTTP status is meaningful:
`400` validation · `401` unauthenticated/invalid credential ·
`403` authenticated-but-wrong-role · `404` scoped-resource-missing ·
`409` conflict (stock, inactive offer) · `429` rate limited · `5xx` server.

**Money:** every monetary value is a JSON **string** `"620000.00"`, never a
number. The client must treat it as opaque display data.

**Localized text:** `{ "ru": "...", "kk": "...", "en": "..." }` on every
name/description.

**Ops endpoints:** `GET /health` only (200 `{"status":"ok"}` /
503 `{"status":"error"}`). **No `/readiness`, no `/metrics`, no audit-log
table/endpoint.** Admin status changes are not currently recorded in an
audit trail.

---

## 2. Auth, sessions, RBAC (Stage 9)

| Piece | How it works |
|---|---|
| **Access token** | JWT HS256, claims `{uid, role, iat, exp}`, TTL 15 min (`JWT_ACCESS_TTL_MINUTES`). Returned in the **login/refresh response body**. |
| **Refresh token** | 256-bit random, **SHA-256 hashed** in `auth_sessions`, TTL 30 days. Delivered to the browser as an **HttpOnly, SameSite=Lax cookie scoped to `Path=/api/v1/auth`**. Raw value never stored, never logged, never in a normal response body. |
| **Rotation** | every `POST /auth/refresh` revokes the old session row and inserts a new one (transaction). |
| **Reuse detection** | presenting an already-revoked refresh token ⇒ **all** of that user's sessions are revoked. |
| **`RequireAuth`** | extracts `Bearer`, parses JWT, then **re-loads the user fresh from Postgres every request** — the JWT role/active claims are only a hint. Deactivating a user or seller takes effect immediately, even with a still-valid access token. |
| **RBAC** | `RequireRole("admin")` / `RequireAnyRole(...)` + `RequireActiveSeller()` (role==seller AND linked `sellers` row active). |
| **Rate limiting** | in-process fixed-window per-IP on `/auth/login|register|refresh` only. Not distributed; resets on restart. |
| **CORS** | exact-origin echo of `FRONTEND_URL` + `Access-Control-Allow-Credentials: true`; never `*`. An unapproved origin gets **no** `Access-Control-*` headers. |
| **CSRF** | header-bearer auth for all `/me`,`/seller`,`/admin` mutations (immune by construction); `SameSite=Lax` + narrow path for the two cookie-only endpoints. |

**Roles:** `customer` (default, only role registration can create) ·
`seller` (has a linked `sellers` row; `seller_id` surfaced on `/auth/me`) ·
`admin` (seed/DB only — no endpoint promotes anyone to admin or seller).

**`auth_sessions`** columns: `id, user_id, refresh_token_hash (unique),
expires_at, created_at, last_used_at, revoked_at, user_agent, ip_address`.

### ⚠️ Mobile-relevant gap — see `AUTH_COMPAT.md`

`POST /auth/login` / `/register` put the refresh token **only** in a
`Set-Cookie` header; `POST /auth/refresh` / `/logout` read it **only** from
the request cookie (`c.Cookie("refresh_token")`), never the body. A native
Dio client has no browser cookie jar semantics. It *can* work unchanged by
manually echoing the cookie value as a `Cookie:` header — but the clean fix
is a ~15-line backward-compatible backend extension (proposed for F2, needs
approval). **Web auth must not change.**

---

## 3. Domain model (tables → what the client sees)

| Table(s) | Public read | Private (owner) |
|---|---|---|
| `users` | — | `/auth/me` (id, email, phone, full_name, role, is_active, seller_id, counts) |
| `sellers` | `/sellers`, `/sellers/:id`, `/sellers/:id/products` (name, slug, rating, verified, counts — **no** email/phone/finance) | seller derives own id from auth |
| `categories` | `/categories` (tree via `parent_id`, `child_count`), `/categories/:id` | admin CRUD |
| `products` + `product_images` | `/products` (card: best-offer price, discount, rating, `seller_count`, `primary_image`), `/products/:id` (detail: `images[]`, `best_offer`, `seller_count`) | admin CRUD |
| `seller_offers` | `/products/:id/offers` (one row per seller: price, old_price, delivery_days, `available_quantity`, seller rating/verified) | `/seller/offers` (CRUD), `/seller/offers/:id/status` |
| `inventory` | folded into offers (`available_quantity`) | `/seller/inventory`, `PATCH /seller/inventory/:offerId` (`available_quantity`); `reserved_quantity`, `is_low_stock` (threshold **5**, backend-computed) |
| `favorites` | — | `/me/favorites` (GET list, `POST/DELETE /me/favorites/:productId`) |
| `carts` + `cart_items` | — | `/me/cart` — keyed by **`seller_offer_id`** (same product from 2 sellers = 2 lines); each line has `is_available`, `line_total`; `summary { item_count, subtotal }`. Prices always re-read server-side. |
| `addresses` | — | `/me/addresses` CRUD + `PATCH /me/addresses/:id/default` (one default enforced) |
| `orders` + `order_items` + `payments` | — | `POST /me/orders` (body `{address_id, payment_provider}` + `Idempotency-Key` header), `/me/orders`, `/me/orders/:orderId` (delivery snapshot, items, `subtotal/discount_total/delivery_total/total`, payment). Customer view has **no** commission fields. |
| `commissions`, `seller_balances` | — | seller: `/seller/finance` (`gross_sales`, `commission_total`, `seller_net_total`, `pending_balance`, `available_balance`, `paid_out_total`); `/seller/orders`, `/seller/orders/:id` (per-seller lines only, with commission + seller_amount). **Marketplace-authoritative — client never computes these.** |
| `payouts` | — | seller: `/seller/payouts` (GET), `POST /seller/payouts` (`{amount}` + `Idempotency-Key`; draws from `available` only; always created `pending`) |
| `reviews` | `/products/:id/reviews` (visible only, `user_display_name`, no PII) | admin moderation only |

### Backend gaps that limit the mobile scope

1. **No "write a review" endpoint.** Reviews are read-only for customers;
   only admins can change visibility. Mobile can *show* reviews, not
   submit them, until the backend adds `POST /products/:id/reviews`.
2. **No product Q&A endpoint.** The web has a `ProductQuestions.js`
   component but it is mock-only. Skip on mobile.
3. **Seller orders are read-only** — no per-seller fulfilment entity, so
   no "mark shipped" from mobile (matches web).
4. **No order cancellation / return endpoint** for customers.
5. **No push-notification / device-token infrastructure.**
6. **No `/auth/sessions` list** for "manage your devices" (only
   `logout-all`).
7. **Payment providers are all mock** (`card`, `kaspi_mock`,
   `apple_pay_mock`, `google_pay_mock`) — no real PSP, no 3-D Secure.
8. **No search suggestions / autocomplete endpoint** — search is a
   `?search=` substring filter on `/products`.
9. **Cart/favorites require auth** — there is no anonymous cart; the web
   deliberately gates them behind login. Mobile follows the same rule.

---

## 4. Web frontend architecture (reference for UX + contracts)

**Stack:** Next.js 15 App Router, React 18, plain CSS (CSS variables), **no
UI library**, no TypeScript. Context-based state.

**Contexts** (`frontend/context/`): `ThemeProvider` (dark / `vivid`=light,
persisted `mp_theme`) · `LanguageProvider` (`ru`/`kk`/`en`, persisted
`mp_lang`, `t(key)` lookup over `data/translations.js`) ·
`NotificationProvider` · `AuthProvider` (access token in memory via
`lib/api/authToken.js`; silent `/auth/refresh` on mount; `user`,
`role`, `sellerId`, `isAuthenticated`) · `ModalProvider` · `CartProvider`
/ `FavoritesProvider` (short-circuit to empty when logged out; open login
modal on action) · `CompareProvider`.

**API layer** (`frontend/lib/api/`): one `client.js` (`apiFetch`) unwraps
the envelope, attaches `Authorization: Bearer`, `credentials:"include"`,
and does **exactly one** silent refresh+retry on a 401 (dedup'd, never a
loop); on refresh failure fires `onSessionExpired` → `AuthContext`
clears the user. Per-resource modules (`products.js`, `cart.js`,
`seller*.js`, `admin*.js`, …) are thin wrappers. `adapters.js` maps API
JSON to the legacy component shape.

**Design tokens** (`frontend/styles/variables.css`) — ported verbatim into
`lib/core/theme/app_colors.dart`:

| role | dark | light |
|---|---|---|
| bg | `#0A0B0D` | `#FFFFFF` |
| surface | `#15171B` | `#FFFFFF` |
| border | `#2A2D34` | `#E5E7EB` |
| text | `#F3F4F6` | `#111111` |
| accent | `#4F8DFF` | `#DA2C55` |
| accent-2 | `#FFB648` | `#C2410C` |
| radius | 6 / 10 / 14 / 18 / 24 | same |
| motion | 140 / 200 / 300 ms | same |

**Screens** (web): home (hero slider, category grid, flash sale, 4 product
rails) · catalog (filters sidebar, sort, grid, pagination) · product
(gallery, info, seller offers, tabs: description/reviews/questions,
recommendations, recently-viewed) · seller public page · favorites · cart
· checkout (address + mock payment) · profile (+ `/profile/orders/[id]`) ·
seller-dashboard (11 sub-panels: dashboard/products/inventory/orders/
finance/analytics/reviews/messages/promo/settings) · admin (14 panels).

**Recurring UI states:** loading skeletons, empty states, error+retry,
toasts, modals (`Modal.js`), drawers (`Drawer.js`), filter sheets, rating
stars, bar charts.

---

## 5. What the mobile app needs

### A. Customer app (primary)
Home · Catalog (search, category, sort, filter sheet, 2-col grid, infinite
scroll, pull-to-refresh) · Product detail (gallery, **multi-seller offers**,
reviews read-only, sticky Add-to-cart / Buy-now) · Favorites (`/me/favorites`)
· Cart (`/me/cart`, grouped by seller) · Checkout (address → mock payment →
`Idempotency-Key` order → success) · Orders + Order detail · Profile
(`/auth/me`, addresses, language, theme, logout) · Login / Register.

### B. Seller section (role == seller, shown via Profile + optional 6th tab)
Dashboard (metric cards) · Offers (cards, add/edit/activate) · Inventory
(available/reserved/low-stock, edit via sheet) · Orders (read-only,
seller lines only) · Finance (gross/commission/net/pending/available/paid)
· Payouts (list + request with `Idempotency-Key`).

### C. Admin — **not in the mobile app.**
14 data-dense moderation panels, no mobile-shaped equivalent, and the
backend exposes no admin action the platform needs on a phone. `role ==
admin` on mobile shows a single "administration is available in the web
version" notice (`/admin` route). Revisit only on explicit request.

---

## 6. Risks / decisions carried into F1

| # | Item | Decision |
|---|---|---|
| R1 | Refresh endpoint is cookie-only | F1 ships a `TokenRefresher` seam; F2 proposes a tiny backward-compatible backend extension (`AUTH_COMPAT.md`). No web change. |
| R2 | No review-submit endpoint | Mobile shows reviews read-only; note for a future backend stage. |
| R3 | Money as decimal strings | `Money` util formats only; never parses for arithmetic. |
| R4 | Cart keyed by `seller_offer_id` | Cart models keep `seller_offer_id`; UI groups by seller; never merges lines. |
| R5 | All-mock payments | Checkout offers the 4 mock providers; no PSP SDK. |
| R6 | No push infra | Out of scope until the backend adds device tokens. |
| R7 | LAN/HTTP dev on device | `network_security_config.xml` + `--dart-define`; production HTTPS only. |
| R8 | Riverpod 3 | `Notifier`/`NotifierProvider` (not the deprecated `StateNotifier`). |
