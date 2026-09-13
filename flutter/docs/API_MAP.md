# API Map — Go REST API → Flutter

Base URL: `${API_BASE_URL}` (e.g. `http://10.0.2.2:8081/api/v1`).
Envelope: `{data}` / `{data,meta}` / `{error:{code,message}}`.
Auth: `Authorization: Bearer <access jwt>` unless "public".
"Flutter target" = the stage that builds it and the repository/screen.

## Auth

| Feature | Endpoint | Method | Auth | Role | Request | Response `data` | Flutter target |
|---|---|---|---|---|---|---|---|
| Register | `/auth/register` | POST | public (rate-limited) | → customer | `{email?, phone?, full_name, password}` | `User` | F2 `AuthRepository.register` |
| Login | `/auth/login` | POST | public (rate-limited) | any | `{email?\|phone?, password}` | `{user, access_token, expires_at}` + `Set-Cookie: refresh_token` | F2 `AuthRepository.login` |
| Current user | `/auth/me` | GET | yes | any | — | `UserDetail {id,email,phone,full_name,role,is_active,seller_id,orders_count,favorites_count,addresses_count}` | F2 `AuthRepository.me` |
| Refresh | `/auth/refresh` | POST | refresh cookie **only** | any | (cookie) | `{access_token, expires_at}` + rotated cookie | F2 `AuthRepository.refresh` — see `AUTH_COMPAT.md` |
| Logout | `/auth/logout` | POST | refresh cookie | any | (cookie) | `{logged_out:true}` | F2 |
| Logout all | `/auth/logout-all` | POST | yes | any | — | `{logged_out:true}` | F2 |

## Public catalog (no auth)

| Feature | Endpoint | Method | Query | Response | Flutter target |
|---|---|---|---|---|---|
| Categories tree | `/categories` | GET | — | `Category[]` (`parent_id`, `child_count`, localized `name`) | F3 `CatalogRepository.categories` |
| Category | `/categories/:id` | GET | — | `Category` | F3 |
| Products list | `/products` | GET | `search, category, category_id, seller, brand, min_price, max_price, rating, sort(price_asc\|price_desc\|rating_desc\|newest\|discount_desc), limit(≤100), offset` | `ProductCard[]` + `meta` | F3 `CatalogRepository.products` (infinite scroll) |
| Product detail | `/products/:id` | GET | — | `ProductDetail {images[], best_offer, seller_count, localized name/description}` | F3 `ProductRepository.detail` |
| Product offers | `/products/:id/offers` | GET | — | `Offer[]` (per-seller: price, old_price, delivery_days, available_quantity, seller rating/verified) | F3 `ProductRepository.offers` (multi-seller UI) |
| Product reviews | `/products/:id/reviews` | GET | `limit, offset` | `PublicReview[]` + `meta` (visible only) | F3 (read-only) |
| Sellers list | `/sellers` | GET | — | `SellerCard[]` | F3 |
| Seller (public) | `/sellers/:id` | GET | — | `SellerDetail` | F3 |
| Seller products | `/sellers/:id/products` | GET | `limit, offset` | `SellerProductItem[]` + `meta` (this seller's own price) | F3 |
| Health | `/health` | GET | — | `{status:"ok"}` | F1 optional diagnostics |

## Customer-private (`/me/*`, auth = customer or any role)

| Feature | Endpoint | Method | Request | Response | Flutter target |
|---|---|---|---|---|---|
| Favorites list | `/me/favorites` | GET | — | `ProductCard[]` | F4 `FavoritesRepository` |
| Add favorite | `/me/favorites/:productId` | POST | — | `{favorited:true}` | F4 |
| Remove favorite | `/me/favorites/:productId` | DELETE | — | `{favorited:false}` | F4 |
| Cart | `/me/cart` | GET | — | `Cart {items[], summary{item_count,subtotal}}` (line keyed by `seller_offer_id`) | F4 `CartRepository` |
| Add to cart | `/me/cart/items` | POST | `{seller_offer_id, quantity}` | `Cart` | F4 |
| Update qty | `/me/cart/items/:itemId` | PATCH | `{quantity}` | `Cart` | F4 |
| Remove line | `/me/cart/items/:itemId` | DELETE | — | `Cart` | F4 |
| Clear cart | `/me/cart` | DELETE | — | `Cart` | F4 |
| Addresses | `/me/addresses` | GET | — | `Address[]` | F4 `AddressRepository` |
| Add address | `/me/addresses` | POST | `{title?, city, street, house, apartment?, postal_code?, is_default?}` | `Address` | F4 |
| Update address | `/me/addresses/:id` | PUT | same | `Address` | F4 |
| Set default | `/me/addresses/:id/default` | PATCH | — | `Address` | F4 |
| Delete address | `/me/addresses/:id` | DELETE | — | `{deleted:true}` | F4 |
| Create order | `/me/orders` | POST | `{address_id, payment_provider}` + header `Idempotency-Key` | `OrderDetail` | F5 `OrderRepository.create` |
| Orders list | `/me/orders` | GET | — | `OrderSummary[]` (status, total, item_count, items_preview) | F5 |
| Order detail | `/me/orders/:orderId` | GET | — | `OrderDetail` (delivery snapshot, items, totals, payment) — ownership enforced | F5 |

## Seller-private (`/seller/*`, auth + role==seller + active seller acct)

Seller id is **always** derived from the authenticated user — it never
appears in a URL.

| Feature | Endpoint | Method | Request | Response | Flutter target |
|---|---|---|---|---|---|
| Dashboard | `/seller/dashboard` | GET | — | `SellerDashboardSummary` (sales_today, orders_today/total, pending/available_balance, active_offers, low_stock_offers, rating) | F6 `SellerRepository.dashboard` |
| Offers list | `/seller/offers` | GET | `search, status(active\|inactive), low_stock, sort, limit, offset` | `SellerOfferItem[]` + `meta` | F6 |
| Create offer | `/seller/offers` | POST | `{product_id, sku, price, old_price?, delivery_days, stock}` | `{id}` | F6 |
| Update offer | `/seller/offers/:offerId` | PUT | `{sku, price, old_price?, delivery_days}` | `{updated:true}` | F6 |
| Offer status | `/seller/offers/:offerId/status` | PATCH | `{is_active}` | `{updated:true}` | F6 |
| Inventory | `/seller/inventory` | GET | — | `SellerInventoryItem[]` (available, reserved, is_low_stock) | F6 |
| Update stock | `/seller/inventory/:offerId` | PATCH | `{available_quantity}` | `{updated:true}` | F6 |
| Seller orders | `/seller/orders` | GET | `limit, offset` | `SellerOrderSummary[]` + `meta` (seller lines only) | F6 (read-only) |
| Seller order | `/seller/orders/:orderId` | GET | — | `SellerOrderDetail` (this seller's lines, commission, seller_amount, delivery) | F6 |
| Finance | `/seller/finance` | GET | — | `SellerFinanceSummary` (gross, commission, net, pending, available, paid_out) | F6 |
| Payouts | `/seller/payouts` | GET | — | `Payout[]` | F6 |
| Request payout | `/seller/payouts` | POST | `{amount}` + header `Idempotency-Key` | `Payout` (status `pending`) | F6 |

## Admin (`/admin/*`) — **NOT built in mobile**

`GET /admin/overview`, `/admin/users`, `/admin/sellers`, `/admin/products`,
`/admin/categories`, `/admin/orders`, `/admin/payments`,
`/admin/commissions`, `/admin/payouts`, `/admin/reviews` (+ status/detail
sub-routes). Mobile shows a "web only" notice for `role == admin`.

## Error codes the client maps to localized copy

`INVALID_CREDENTIALS` `ACCOUNT_DISABLED` `SESSION_EXPIRED` `UNAUTHORIZED`
`FORBIDDEN` `VALIDATION_ERROR` `WEAK_PASSWORD` `EMAIL_ALREADY_EXISTS`
`PHONE_ALREADY_EXISTS` `INSUFFICIENT_STOCK` `OFFER_UNAVAILABLE`
`CART_EMPTY` `TOO_MANY_REQUESTS` `*_NOT_FOUND` — plus synthetic
`NETWORK_ERROR` `TIMEOUT` `UNKNOWN_ERROR` (see `core/errors/api_exception.dart`,
`core/localization/strings/*`).
