# Nova Marketplace — Backend

Go + Gin REST API backend for the Nova Marketplace project. This is a
**modular monolith**: no ORM, no microservices — plain `pgx`/`pgxpool` against
PostgreSQL 17, organized into clear handler → service → repository layers.

> **Stage 3 (this stage): Catalog REST API.** The public, read-only
> marketplace catalog — categories, products (search/filter/sort/
> pagination), product detail, seller offers, sellers, and a seller's
> product listing — is now a real REST API backed by the Stage 2 schema and
> seed data. Still no cart/favorites/orders/reviews-write/seller-dashboard/
> admin API, no auth, and no frontend integration — see "What's next" below.

## Stack

- Go 1.25
- [Gin](https://github.com/gin-gonic/gin) — HTTP router
- [pgx/v5](https://github.com/jackc/pgx) + `pgxpool` — PostgreSQL driver, no ORM
- PostgreSQL 17
- [Goose](https://github.com/pressly/goose) — SQL migrations, embedded as a library (see `cmd/migrate`) rather than a globally-installed CLI
- Docker / Docker Compose

## Architecture

```
Browser → Next.js frontend → REST API (/api/v1) → Gin → Service layer → Repository layer → pgxpool → PostgreSQL 17
```

```
backend/
├── cmd/
│   ├── api/main.go            entrypoint: wires config → db → handlers → router → server, handles graceful shutdown
│   ├── migrate/main.go        Goose migration runner: go run ./cmd/migrate <up|down|status|redo|reset|...>
│   └── seed/main.go           runs seeds.Run() against the configured database
├── internal/
│   ├── config/                 env var loading + validation
│   ├── database/                pgxpool construction (single pool for the whole app)
│   ├── models/                   read-model/DTO types shared by all three layers below (no SQL, no HTTP)
│   ├── repositories/             all SQL lives here — category/product/seller repos + the shared "valid offer" CTEs
│   ├── services/                 query validation, best-offer/availability rules, not-found handling — no SQL, no Gin
│   ├── handlers/                 HTTP layer — parses input, calls services, writes responses, no SQL
│   ├── middleware/               request ID, structured logging, panic recovery, CORS
│   ├── response/                 { data } / { data, meta } / { error } JSON envelope helpers
│   ├── routes/                   gin.Engine assembly — the only place that knows the full URL map
│   └── testutil/                 shared test-DB helper (skips integration tests when no DB is configured)
├── migrations/                  18 Goose SQL migrations — the marketplace schema (see below)
├── seeds/                       demo data: package seeds (data.go, seed.go, seed_demo.go) + tests
├── Dockerfile                    multi-stage build → small alpine runtime image (API server only)
├── docker-compose.yml            postgres + backend, for local dev
└── .env.example
```

`migrate`/`seed` are dev-time tools; only `cmd/api` ships in the Docker
runtime image. Layering is strict: handlers never contain SQL, services
never import Gin, repositories never see a `gin.Context` — see "Catalog
REST API" below for the full endpoint/query-param reference.

## Environment variables

Copy `.env.example` to `.env` for local (non-Docker) development:

```bash
cp .env.example .env
```

| Variable | Required | Description |
|---|---|---|
| `APP_ENV` | no (default `development`) | `development` \| `staging` \| `production` \| `test` |
| `PORT` | no (default `8080`) | HTTP port the API listens on |
| `DATABASE_URL` | one of this or the `DB_*` set below | Full PostgreSQL connection string; takes precedence over `DB_*` when set |
| `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASSWORD` / `DB_SSLMODE` | see above | Used to build the connection string when `DATABASE_URL` is not set |
| `FRONTEND_URL` | **yes** | Exact origin allowed by CORS, e.g. `http://localhost:3000` |
| `JWT_ACCESS_SECRET` | **yes** | HMAC secret used to sign access JWTs. Must be at least 32 characters; the server refuses to start otherwise. Generate one with `openssl rand -base64 48`. |
| `JWT_ACCESS_TTL_MINUTES` | no (default `15`) | Access token lifetime, in minutes |
| `REFRESH_TOKEN_TTL_DAYS` | no (default `30`) | Refresh session lifetime, in days |
| `COOKIE_SECURE` | no (default `false`) | Set `true` in any deployment served over HTTPS. Required to be `true` when `APP_ENV=production` (startup fails otherwise). |
| `COOKIE_DOMAIN` | no (default empty = host-only cookie) | Set only if the API and frontend share a parent domain in production |

`config.Load()` / `cmd/migrate` / `cmd/seed` all read the same variables, so
one `.env` covers the API server and the dev tooling.

## Running locally (no Docker)

Requires a PostgreSQL 17 instance reachable with the configured credentials.

```bash
cd backend
go mod tidy
cp .env.example .env   # then edit as needed
export $(grep -v '^#' .env | xargs)   # or use your preferred env loader
go run ./cmd/api
```

## Running with Docker Compose

```bash
cd backend
docker compose up --build
```

This starts PostgreSQL 17 (`postgres:17-alpine`, with a persistent
`postgres_data` volume and a `pg_isready` healthcheck) and the backend API.
The backend container waits for Postgres to report **healthy**, not just
"started", before it is allowed to start.

- Backend: http://localhost:8080
- PostgreSQL: `localhost:5432` (user/password/db: `postgres`/`postgres`/`marketplace` — local dev only, override via environment for anything else). If port 5432 is already taken on your machine, override the *host* side only: `POSTGRES_HOST_PORT=5540 docker compose up --build` (the container's internal port and `DB_PORT` stay 5432).

Stop with `docker compose down` (add `-v` to also drop the Postgres volume —
see the "reset" section below before doing that).

## Health check

```bash
curl -i http://localhost:8080/health
```

- `200 { "status": "ok" }` — database reachable
- `503 { "status": "error", "message": "database unavailable" }` — database unreachable (no connection details or credentials are ever included)

## Database schema (Stage 2)

18 tables, applied as sequential Goose migrations in `migrations/`:

```
users → sellers → categories → products → product_images → seller_offers
→ inventory → favorites → carts → cart_items → addresses → orders
→ order_items → payments → commissions → seller_balances → payouts → reviews
```

**Marketplace model**: a `product` is pure catalog identity (brand, names,
description) with **no** seller column. Any number of `sellers` can list the
same product as their own `seller_offer` (own SKU, price, delivery time).
`cart_items` and `order_items` reference `seller_offer_id`, not
`product_id` — a buyer always buys a *specific seller's* offer.

**Money**: every persisted amount is `NUMERIC(14,2)`. Application code
(seed and, later, order logic) does arithmetic in integer cents internally
and formats to `"12345.67"` strings when binding query parameters —
`float64` is never used for money, even in the seed script.

**ON DELETE strategy** (documented per-migration as SQL comments):
- Pure detail rows with no independent meaning (`product_images`,
  `inventory`, `favorites`, `cart_items`, `carts`, `addresses`, `payments`,
  `seller_balances`, `reviews`) → `CASCADE`.
- Core catalog identity, protected from accidental mass deletion
  (`products.category_id`, `categories.parent_id`, `seller_offers.seller_id`,
  `seller_offers.product_id`, `sellers.user_id`) → `RESTRICT`.
- Financial/historical records that must survive deleting the "current"
  entity (`orders.user_id`, `order_items.seller_id`, `commissions.seller_id`,
  `payouts.seller_id`) → `RESTRICT` — deactivate (`is_active = false`)
  instead of deleting.
- `order_items.product_id` / `order_items.seller_offer_id` → `SET NULL` —
  the snapshot columns (`product_name`, `sku`, `unit_price`, ...) already
  preserve what the buyer saw, so the catalog can be cleaned up later
  without losing history.

**Indexes**: added wherever a lookup isn't already covered by a `UNIQUE`
constraint or the leading column of a composite unique/primary key (e.g.
`sellers.slug`, `inventory.seller_offer_id`, and `seller_offers.seller_id`
via `UNIQUE(seller_id, sku)` need no separate index).

## Migrations (Goose)

Goose runs as an embedded library via `cmd/migrate` — no global CLI install
needed, and it always uses the same config/connection logic as the API
server:

```bash
go run ./cmd/migrate status   # what's applied / pending
go run ./cmd/migrate up       # apply all pending migrations
go run ./cmd/migrate down     # roll back exactly one migration
go run ./cmd/migrate redo     # down + up the most recent migration
go run ./cmd/migrate reset    # roll ALL migrations back (down to empty) — see warning below
```

> ⚠️ `reset` and repeated `down` calls **drop tables and all data in them**.
> Only ever run these against your local Stage 2 development database (the
> `postgres` service in `docker-compose.yml`, or a local instance you
> created yourself) — never against a shared or production database. There
> is no separate "production migrate" command in this stage; when a real
> deployment exists, migrations there should be applied deliberately as
> part of a release process, not by casually running `reset`.

## Seed data

```bash
go run ./cmd/seed
```

Populates: 12 users (1 admin, 8 seller accounts, 3 customers), 8 sellers, 13
categories (10 root + 3 children, demonstrating the category tree), 40
products, 80 product images, 81 seller offers across those products (27
products have offers from 2–3 different sellers — real marketplace
behaviour, not a single-seller catalog), inventory for every offer, 3
addresses, 15 favorites, 3 carts with 6 items, 40 reviews, 2 demo orders
(with payments, order line snapshots, commissions, and seller balance
updates), and 1 demo payout.

Catalog content (names, categories, sellers, prices) is intentionally
aligned with `frontend/data/*.js` — same marketplace, now living in
PostgreSQL — per the Stage 2 brief. The frontend itself was not modified.

**Idempotency**: safe to run repeatedly.
- Entities with a natural business key (`users.email`, `sellers.slug`,
  `categories.slug`, `products.slug`, `seller_offers(seller_id, sku)`,
  `carts.user_id`, `favorites(user_id, product_id)`,
  `cart_items(cart_id, seller_offer_id)`, `reviews(user_id, product_id)`,
  `seller_balances.seller_id`) use
  `INSERT ... ON CONFLICT (<key>) DO UPDATE ... RETURNING id`, so re-running
  updates the same rows and never duplicates them.
- `product_images` has no natural key (purely decorative rows) — the seed
  deletes and re-inserts a product's images each run.
- `orders` (and everything chained off an order: `order_items`, `payments`,
  `commissions`, `seller_balances` updates) and `addresses` are
  transactional/accumulating records with no sensible upsert key, so the
  seed checks "does this customer already have any?" first and skips if so.
- The whole run is one PostgreSQL transaction — if anything fails partway,
  everything rolls back and no half-seeded data is left behind.

Verified by running the seed three times in a row against the same
database: row counts were identical after run 2 and run 3 for every table.

**Local dev credentials (Stage 9)**: every seeded user (all 12 — the admin,
all 8 sellers, and all 3 customers) shares the same known password so any
of them can be used to log in locally:

| Field | Value |
|---|---|
| Password (all seeded accounts) | `NovaDev2026` |
| Admin | `admin@nova.kz` |
| Sellers | e.g. `techstore@nova.kz`, `gadgetpro@nova.kz`, ... (see `backend/seeds/seed.go` for the full list) |
| Customers | e.g. `aigerim@example.com`, `nurlan@example.com`, `beautylab@nova.kz` |

The password is hashed once with bcrypt (cost 12) and written to every
seeded row's `password_hash` via `ON CONFLICT ... DO UPDATE`, so re-running
the seed always leaves these accounts in a known-good, login-able state.
This is a local development convenience only — never seed a shared or
production database with a known password.

## Inspecting the database

```bash
docker compose exec postgres psql -U postgres -d marketplace

# inside psql:
\dt                          -- list tables
\d seller_offers              -- describe a table: columns, constraints, indexes, FKs
SELECT COUNT(*) FROM products;
```

Proof that multiple sellers can sell the same product:

```sql
SELECT p.id, p.name_ru, COUNT(DISTINCT so.seller_id) AS seller_count
FROM products p
JOIN seller_offers so ON so.product_id = p.id
GROUP BY p.id, p.name_ru
HAVING COUNT(DISTINCT so.seller_id) > 1
ORDER BY seller_count DESC;
```

## Resetting ONLY the local development database

To start completely fresh (empty schema, no data) on your **local dev**
Postgres only:

```bash
cd backend
docker compose down -v   # removes the postgres_data volume — local dev data only
docker compose up -d postgres
go run ./cmd/migrate up
go run ./cmd/seed
```

Do not run `docker compose down -v` against any environment other than your
own local `docker-compose.yml` stack — it deletes the Postgres data
directory permanently.

## Catalog REST API (Stage 3)

All endpoints are under `/api/v1`, read-only, and require no authentication
(auth is Stage 9).

| Method & path | Description |
|---|---|
| `GET /api/v1/categories` | Active categories (root + children), sorted by `sort_order` then `id` |
| `GET /api/v1/categories/:id` | One category, or 404 |
| `GET /api/v1/products` | Search/filter/sort/paginated product list — see query params below |
| `GET /api/v1/products/:id` | Full product detail, including its best offer |
| `GET /api/v1/products/:id/offers` | Every purchasable offer for that product, cheapest first |
| `GET /api/v1/sellers` | Active sellers |
| `GET /api/v1/sellers/:id` | One seller's public profile, or 404 |
| `GET /api/v1/sellers/:id/products` | Products this seller currently sells, priced at **their own** offer |

### `GET /api/v1/products` query parameters

| Param | Example | Behaviour |
|---|---|---|
| `search` | `search=iphone` | Case-insensitive `ILIKE` on `name_ru`/`name_kk`/`name_en`/`brand` |
| `category` | `category=electronics` | Filter by category **slug** |
| `category_id` | `category_id=3` | Filter by category id (use either `category` or `category_id`) |
| `seller` | `seller=techstore` or `seller=1` | Filter by seller slug *or* numeric id — only products with a valid offer from that seller |
| `brand` | `brand=Apple` | Case-insensitive exact match |
| `min_price` / `max_price` | `min_price=100000&max_price=500000` | Applied to each product's **effective marketplace price** (its cheapest valid offer) — not a `products` table column, since price lives on `seller_offers` |
| `rating` | `rating=4` | `products.rating >= 4`; must be 0–5 |
| `sort` | `sort=price_asc` | One of `price_asc`, `price_desc`, `rating_desc`, `newest`, `discount_desc` — anything else is `400 INVALID_SORT` |
| `limit` | `limit=20` | Default 20, must be a positive integer, silently clamped to 100 if higher |
| `offset` | `offset=0` | Default 0, must be zero or positive |

Invalid values (`limit=-5`, `rating=9`, `min_price=abc`, an unknown `sort`)
return `400` with a specific error code (`INVALID_LIMIT`, `INVALID_RATING`,
`INVALID_MIN_PRICE`, `INVALID_SORT`, ...) — never silently ignored. A
filter that legitimately matches nothing returns `200` with
`{ "data": [], "meta": { "total": 0, ... } }`, not `404`.

### Best offer rule (centralized in `repositories.bestOfferRankedCTE`)

A product's list price, and the `best_offer` in its detail response, is
always its **cheapest valid offer** — ties broken by higher seller rating,
then lower offer id, for a fully deterministic result. The same rule
computes `GET /products/:id/offers`' sort order (there, every valid offer
is returned, not just the best one).

### Public availability rule (centralized in `repositories.validOffersCTE`)

An offer only counts as purchasable — and therefore only then does it
affect price/seller_count/appear in the offers list — when **all** of:
`seller_offers.is_active`, the seller's `is_active`, and the product's
`is_active` are true, **and** its `inventory.available_quantity > 0`. A
product with zero such offers is excluded from `GET /products` entirely
(so the catalog never shows something nobody can currently buy), but its
own detail page (`GET /products/:id`) still resolves — `best_offer` is
simply `null` and `seller_count` is `0`, since the product itself may still
be a real, browsable catalog entry temporarily out of stock everywhere.

### Money & discount serialization

Every price is a decimal **string** (`"620000.00"`), never a JSON number —
`internal/models.Money` is a named `string` type, and every repository
query casts `NUMERIC` columns with `::text` before scanning, so no
`float64` ever touches a monetary value on the request path (query-param
bounds like `min_price` are validated by regex and bound straight into
`$n::numeric`, again with no float parsing). `discount_percent` is a plain
JSON integer, computed as `round((old_price - price) / old_price * 100)`,
guarded to `0` whenever `old_price` is missing, zero, or not actually
higher than `price`.

### Example requests

```bash
curl -s http://localhost:8080/api/v1/categories
curl -s http://localhost:8080/api/v1/products
curl -s "http://localhost:8080/api/v1/products?limit=5"
curl -s "http://localhost:8080/api/v1/products?search=iphone"
curl -s "http://localhost:8080/api/v1/products?sort=price_asc"
curl -s "http://localhost:8080/api/v1/products?category=electronics&min_price=100000&rating=4&sort=price_asc&limit=10"
curl -s http://localhost:8080/api/v1/products/1
curl -s http://localhost:8080/api/v1/products/1/offers
curl -s http://localhost:8080/api/v1/sellers
curl -s http://localhost:8080/api/v1/sellers/1
curl -s http://localhost:8080/api/v1/sellers/1/products
```

### Field naming: nested `name`/`category`, not `name_ru`

The public JSON always nests localized text as `"name": {"ru","kk","en"}`
(and embeds a compact `category: {id, slug, name}` on every product) — this
applies uniformly to categories and products, matching the shape already
shown in the products example in the Stage 3 brief, rather than mixing that
with a flat `name_ru`/`name_kk`/`name_en` convention for categories alone.

## Development workflow

Run after every change, before committing:

```bash
gofmt -w .
go vet ./...
go test ./...
go build ./...
```

### Tests

`go test ./...` always passes with **zero configuration** — the
repository (`internal/repositories`) and handler (`internal/handlers`)
integration tests connect to a real database via `internal/testutil` and
`t.Skip()` themselves cleanly when one isn't configured. `internal/services`
has pure unit tests for query validation (no DB needed). To actually run
the integration tests, point `go test` at your local dev database the same
way you'd run the API:

```bash
DB_HOST=localhost DB_PORT=5432 DB_NAME=marketplace DB_USER=postgres \
DB_PASSWORD=postgres DB_SSLMODE=disable FRONTEND_URL=http://localhost:3000 \
go test ./... -v
```

Repository tests never hardcode a seed ID — they discover one at runtime
(e.g. "take the first product `List()` returns, then `GetByID()` it"), so
they keep passing even if the seed data changes shape.

## API response format

```jsonc
// single resource
{ "data": { } }

// list
{ "data": [ ], "meta": { "limit": 20, "offset": 0, "total": 100 } }

// error
{ "error": { "code": "PRODUCT_NOT_FOUND", "message": "Product not found" } }
```

Error responses never include SQL text, stack traces, credentials, or
filesystem paths — those are logged server-side only.

## Authentication & authorization (Stage 9)

### Approach

Short-lived **access JWT** (HS256, 15 min default, `JWT_ACCESS_TTL_MINUTES`)
returned in the JSON body of `login`/`register`/`refresh` and held by the
frontend only in memory (a module-scoped JS variable — never
`localStorage`, never a cookie, never React state). Paired with a
long-lived **refresh session** (30 days default, `REFRESH_TOKEN_TTL_DAYS`):
a 256-bit random token, SHA-256 hashed before it is stored in the new
`auth_sessions` table (the raw token is never persisted), delivered to the
browser only via a `Secure` (in production; `COOKIE_SECURE`), `HttpOnly`,
`SameSite=Lax` cookie scoped to `Path=/api/v1/auth` — so it is attached
only to `/auth/refresh` and `/auth/logout`, never to ordinary API calls,
and is never readable from JavaScript (no XSS token theft surface).

Passwords are hashed with **bcrypt, cost 12** (`internal/auth/password.go`)
— never stored, logged, or returned in plaintext.

### Routes

| Route | Auth | Notes |
|---|---|---|
| `POST /api/v1/auth/register` | none (rate-limited) | `{email?, phone?, full_name, password}`, always creates role `customer` — the payload cannot request `seller`/`admin` |
| `POST /api/v1/auth/login` | none (rate-limited) | `{email or phone, password}` → access token + user; sets refresh cookie |
| `POST /api/v1/auth/refresh` | refresh cookie only | rotates the session (old token revoked, new one issued); reused/revoked/expired/unknown token → `401 SESSION_EXPIRED`; reuse of an already-rotated token revokes the *entire* session chain for that user |
| `POST /api/v1/auth/logout` | refresh cookie only | revokes just the current session, clears the cookie |
| `POST /api/v1/auth/logout-all` | access token | revokes every session for the user |
| `GET /api/v1/auth/me` | access token | id/email/phone/full_name/role/seller_id/is_active — never password or token hashes |

Every request that touches `RequireAuth` re-reads the user (and, for
sellers, `sellers.is_active`) fresh from Postgres — it does not trust the
JWT's embedded role/active claims. This is deliberate: disabling a user or
seller account takes effect immediately, even against an access token that
is still cryptographically valid and not yet expired.

#### Native-client transport (`X-Client: nova-mobile`) — additive, Stage F2

A native app has no HttpOnly-cookie semantics. When a request carries the
header `X-Client: nova-mobile`, the transport of the **refresh
credential** changes — and nothing else:

| | Browser (no header) | Native (`X-Client: nova-mobile`) |
|---|---|---|
| `login` / `register` response | refresh token in `Set-Cookie` (HttpOnly), **not** in the body | `{access_token, access_expires_at, refresh_token, refresh_expires_at, user}` in the body, **no cookie**; `register` returns a full session (auto-login) |
| `refresh` / `logout` input | `refresh_token` cookie | `{"refresh_token": "..."}` request body |

Same `AuthService` calls, same rotation, same reuse detection, same
`auth_sessions` table, same rate limits. `X-Client` is **not** an auth or
authz boundary — a browser could send it; it would only opt that request
into body-transport (a worse XSS posture for a browser, which is why the
web client never sends it). See `flutter/docs/AUTH_COMPAT.md`. Tests:
`internal/handlers/auth_mobile_test.go`.

### Private routes: `/me/*`, `/seller/*`, `/admin/*`

The old pattern of trusting a caller-supplied `:userId`/`:sellerId` in the
URL is gone. Every private route now takes its identity exclusively from
the authenticated request context — there is no id in the URL to tamper
with:

- `/api/v1/me/favorites|cart|addresses|orders[/:orderId]` — any
  authenticated user; scoped to `auth.Identity.UserID`.
- `/api/v1/seller/dashboard|offers|inventory|orders|finance|payouts` —
  requires role `seller` **and** an active seller account linked to the
  caller (`RequireRole("seller")` + `RequireActiveSeller()`); scoped to
  the seller row resolved from the authenticated user, never a URL param.
- `/api/v1/admin/*` — requires role `admin`.

`GET /api/v1/sellers`, `/api/v1/sellers/:id`, `/api/v1/sellers/:id/products`
(the **public** seller storefront) are unchanged and still require no auth.

HTTP semantics: `401` = not authenticated / invalid or missing credential;
`403` = authenticated but the wrong role or an inactive linked seller
account; `404` = the resource itself doesn't exist for that (already
authorized) caller.

### CSRF

State-changing calls to `/me/*`, `/seller/*`, `/admin/*` (and login/
register) authenticate via the `Authorization: Bearer` header, which an
attacker page cannot make the browser attach — that alone makes them
immune to classic cookie-riding CSRF. The two endpoints that *do*
authenticate purely via cookie (`/auth/refresh`, `/auth/logout`) are
protected by `SameSite=Lax` (the browser will not attach the cookie to a
cross-site `POST`) plus the cookie's narrow `Path=/api/v1/auth` scope.

### CORS

`internal/middleware/cors.go` never returns `Access-Control-Allow-Origin: *`;
it echoes back only the exact configured `FRONTEND_URL` and sets
`Access-Control-Allow-Credentials: true`. A request from any other
`Origin` receives no `Access-Control-*` headers at all, so a browser
running JS on an unapproved origin cannot read a credentialed response
even if the request itself reaches the server.

### Rate limiting

`internal/auth/ratelimit.go` is a minimal in-process, per-IP fixed-window
limiter applied to `/auth/login`, `/auth/register`, `/auth/refresh`. It is
**not** distributed and resets on restart — adequate to blunt casual
brute-forcing in a single-instance deployment, not a production-grade
solution. A shared store (e.g. Redis) is the natural next step if the API
ever runs behind more than one instance.

### Known limitations / suggested future work

- No email verification or password-reset flow (`email_verified_at` exists
  in the schema for later use; nothing sends real email yet).
- No OAuth/social login, no 2FA.
- Rate limiting is in-process only — swap for a shared store before
  running multiple API replicas.
- Admin role assignment is not exposed via any endpoint — seed data and
  direct DB access are the only ways to create an admin today, by design
  (kept out of scope to avoid privilege-escalation surface).

## What's next (Stage 4)

Connect the Next.js frontend to this Catalog API — home page, catalog
page, product page, and the public seller page switch from
`frontend/data/*.js` mock arrays to real `fetch` calls against
`/api/v1/categories`, `/api/v1/products`, `/api/v1/products/:id`,
`/api/v1/products/:id/offers`, `/api/v1/sellers`, `/api/v1/sellers/:id`,
`/api/v1/sellers/:id/products`. Cart, favorites, checkout and everything
else stay on `localStorage`/mock data until their own backend stage (5+).
No auth yet (Stage 9).
