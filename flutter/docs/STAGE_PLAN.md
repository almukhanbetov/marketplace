# Flutter delivery plan (F1–F7)

Each stage ends with `dart format` clean, `flutter analyze` 0 issues,
`flutter test` green, `flutter build apk --debug` passing — then **STOP**.

## F1 — Foundation ✅ (this stage)
Project, cleaned demo, folder structure, pubspec, go_router, Riverpod,
Dio `ApiClient` (base URL, timeouts, request id, envelope unwrap, error
mapping, **401 refresh-and-retry-once** via a `TokenRefresher` seam),
`flutter_secure_storage` wiring, `--dart-define` env, theme system
(Dark `#0A0B0D` / Light `#FFFFFF`), RU/KAZ/ENG localization foundation,
app shell (5-tab bottom nav), placeholder routes/screens, error models,
Loading/Empty/Error widgets, auth repository interface + skeleton
`AuthController`. **No real login, no catalog.**

## F2 — Authentication ✅ (complete)
Additive backend transport extension (`X-Client: nova-mobile`) — web
unchanged. `AuthRepositoryImpl` (login, register, me, refresh w/ rotation
+ single-flight, logout, logout-all). Real login + register screens
(email/phone + password, loading/error, autofill, show/hide). `AuthState`
(unknown/restoring/authenticated/unauthenticated + transient-failure
flag). Silent session restore on launch behind a splash; network-vs-
invalid distinction. `RefTokenRefresher` wired to the Dio 401 interceptor.
Route guards LIVE (`kEnableRouteGuards = true`): return-to, seller-only
screen, admin → web-only notice. Real profile (identity + logout +
logout-all). Android `allowBackup=false` for the keychain.

## F3 — Public catalog ✅ (complete)
Home (compact top bar, search entry, category strip, promo, 4 API-backed
rails with per-section failure/retry). Catalog (`CatalogController`:
debounced search, category/brand/price/rating filters via bottom-sheet,
sort sheet, active-filter chips, 2-col responsive grid, infinite scroll,
pull-to-refresh, generation-guarded stale-response + Dio cancel-token, no
dup append). Product detail (swipe gallery + fullscreen zoom, price from
selected offer, **multi-seller offer sheet** with best-offer highlight +
selection, expandable description, read-only reviews with "show more",
sticky CTA — cart deferred to F4, no fake state, 404 screen). Public
seller storefront at `/seller/:id` (header + seller-specific-priced grid).
No favorites/cart/checkout wired. Riverpod auto-retry disabled globally.
`cached_network_image` added.

## F4 — Customer state ✅ (complete)
Favorites (`FavoritesController`: `/me/favorites`, optimistic toggle +
rollback, `isFavoriteProvider` per-card, logged-out heart tap → login,
grid screen). Cart (`CartController`: `/me/cart`, backend-confirmed
mutations — every response replaces state, grouped by seller preserving
first-seen order, cart identity = `seller_offer_id` so one product from
two sellers is two lines, qty stepper with stock-limit UX, qty≤1 minus →
confirm-delete, bulk `DELETE /me/cart` clear, bottom-nav `Badge` from
`cartBadgeCountProvider`). Product sticky bar wired: "В корзину" adds the
selected offer, "Купить сейчас" adds + navigates to `/cart` (no order —
that's F5). Addresses (`AddressesController`: `/me/addresses` CRUD, full
create/edit form with autofill hints + not-blank validation, set-default
re-reads the list so the single-default invariant comes from Postgres).
All state is backend-owned: logout clears favorites/cart/addresses in
memory only (never touches the DB row), login reloads. Light bg stays
`#FFFFFF`. No RenderFlex overflow at 360/390/430. RU/KK/EN parity.

## F5 — Checkout / Orders ✅ (complete)
`OrderRepository` + typed models (`OrderListItemModel` / `OrderDetailModel`
/ `OrderItemModel` / `OrderPaymentModel` / `OrderAddressSnapshotModel` /
`CreateOrderResult`) over the existing Stage 6/9 `/me/orders` API — no
backend changes. Real full-screen checkout (`/checkout`, root navigator):
compact seller-grouped cart summary, DB-backed address selector (default
auto-selected, add-address inline), mock payment selector (only the four
backend providers: `card` / `kaspi_mock` / `apple_pay_mock` /
`google_pay_mock`, with a "test payment" notice), sticky total + place-
order CTA. `CheckoutController` (`autoDispose`): one UUID `Idempotency-Key`
per attempt — reused across submit / retry / transport-retry, new only on
`startNewAttempt`; double-submit latched client-side on top of backend
idempotency. Order create sends **only** `{address_id, payment_provider}`
+ the header. On success: cart re-read (never a redundant `DELETE`), order
history refreshed, `pushReplacement` to `/checkout/success` so back can't
resubmit. Success screen (restrained check-mark tween) → view order /
keep shopping. `INSUFFICIENT_STOCK` / `OFFER_UNAVAILABLE` / `CART_EMPTY` /
`ADDRESS_NOT_FOUND` each refresh the relevant controller and show a
localized banner + "back to cart". Orders list (`OrdersController`,
`/me/orders`, pull-to-refresh, cards with thumbnails) and order detail
(`orderDetailProvider.family`, `/me/orders/:id`, items grouped by seller,
historical price + address snapshots, ownership 404). Cart "Оформить
заказ" and product "Купить сейчас" both route to `/checkout` ("Buy now"
adds the offer only if it isn't already a cart line). Profile → Orders row
live. No local order store — history survives restart because it's always
read from Postgres. RU/KK/EN parity. Light bg `#FFFFFF`. No overflow at
360/390/430.

## F6A — Seller foundation + dashboard ✅ (complete)
Seller feature foundation under `features/seller/` (`dashboard/` +
`shared/`, each `data`/`application`/`presentation`). `SellerDashboardRepository`
→ `GET /seller/dashboard` (no backend changes); typed `SellerDashboardModel`
with the exact backend field set (`sales_today`, `orders_today`,
`orders_total`, `pending_balance`, `available_balance`, `active_offers`,
`low_stock_offers`, `low_stock_threshold`, `rating`, `review_count` —
money kept as exact strings). `SellerDashboardController`
(`NotifierProvider.autoDispose`, `ref.mounted` guarded): loading / data /
error+retry / **unavailable** (a 403 from `/seller/*` = the account was
deactivated → safe "seller area unavailable" state with an exit).
Real dashboard screen: store header (name + verified badge from the public
`/sellers/:id` profile, id taken from the auth context — never the UI —
best-effort so a failure there doesn't fail the dashboard) + rating, a
responsive 2/3-col metric-card grid (sales, orders today/total, available
& pending balance, active offers, low stock), and five quick-action cards
(Предложения / Остатки / Заказы / Финансы / Выплаты) that navigate to the
F6B placeholders. Route guard: admin hitting any `/seller/*` now lands on
the web-only notice (not the sellers-only screen). Profile "Кабинет
продавца" entry was already seller-only. RU/KK/EN parity. Light bg
`#FFFFFF`. No overflow at 360/390/430.

## F6B — Seller offers + inventory ✅ (complete)
`features/seller/offers/` and `features/seller/inventory/` (each
`data`/`application`/`presentation`). `SellerOffersRepository` →
`GET/POST/PUT/PATCH /seller/offers`; `SellerInventoryRepository` →
`GET/PATCH /seller/inventory`. Typed `SellerOfferModel` /
`SellerInventoryItemModel` (backend fields only; `id` is the offer id used
for every mutation — never `productId`/`sellerId`; money stays exact
strings). `SellerOffersController` (`autoDispose`, generation-guarded,
server-side search / status filter / low-stock filter, infinite scroll,
per-offer `mutating` set) — every create/edit/status change re-reads the
list and create/status also `ref.invalidate` the dashboard + inventory
(§17). `SellerInventoryController` — per-row PATCH then re-read so the
backend's recomputed `is_low_stock` is authoritative, + dashboard
invalidation. Offers screen: mobile cards (image / product / SKU /
price+old / stock / delivery / active badge), Edit + Activate/Deactivate,
FAB → add. Add flow: `ProductSelectorScreen` over the **public catalog**
(backend search + pagination, never loaded whole) → shared `OfferForm`
(SKU / price / old price / delivery / stock; client validation mirrors
the backend `^[0-9]+(\.[0-9]{1,2})?$` rule, backend authoritative). Edit
flow: same form, no stock field, product/seller immutable. Inventory
screen: rows with low-stock banner + bottom-sheet quantity edit
(validate ≥ 0). Public-catalog sync (deactivate → gone from
`/products/:id/offers` → reactivate → back) is proven by an integration
test, never re-implemented client-side (§13). RU/KK/EN parity. Light bg
`#FFFFFF`. No overflow at 360/390/430.

## F6C — Seller orders ✅ (complete)
`features/seller/orders/` (`data`/`application`/`presentation`).
`SellerOrdersRepository` → `GET /seller/orders` + `GET /seller/orders/:id`
— **read-only**, no mutation methods (§7/§16). Typed `SellerOrderListItem`
/ `SellerOrderDetail` / `SellerOrderItem` (exact backend fields; money as
exact strings; `OrderStatus` + `OrderAddressSnapshotModel` reused from F5).
`SellerOrdersController` (`autoDispose`, generation-guarded, infinite
scroll, pull-to-refresh, auth-listen) + `sellerOrderDetailProvider.family`.
Orders list: mobile cards (number / date / status badge / this seller's
item count / seller gross / commission / net). Detail: **only this
seller's lines** — product snapshot, SKU, qty, unit price, line total,
per-line commission + seller amount, delivery snapshot (the seller needs
it to ship), and gross/commission/net totals. Privacy: the backend
filters `WHERE order_id = ? AND seller_id = ?` and returns
`ORDER_NOT_FOUND` when the seller has no line on the order (can't be
probed) — proven by an integration test on a real multi-seller order
where TechStore and GadgetPro each see only their own disjoint SKUs and
different amounts. Zero status-changing controls on any seller order
screen (asserted by a widget test). Historical snapshots only — never
today's catalog price. RU/KK/EN parity. Light bg `#FFFFFF`. No overflow at
360/390/430.

## F6D — Seller finance + payouts ✅ (complete)
`features/seller/finance/` + `features/seller/payouts/`
(`data`/`application`/`presentation`). `SellerFinanceRepository` →
`GET /seller/finance`; `SellerPayoutRepository` → `GET|POST /seller/payouts`.
Typed `SellerFinanceModel` (gross / commission / net / pending / available /
paid-out — exact backend decimal strings, zero client-side accounting),
`SellerPayoutModel` + `PayoutStatus` (`pending`/`processing`/`paid`/
`rejected`), `CreatePayoutResult`. Finance screen: the **available vs
pending distinction is the headline** — available is a highlighted card
("can be withdrawn"), pending a muted card ("not released — cannot be
withdrawn"), then a gross/commission/net/paid-out breakdown, plus a
"Request payout" button. Payouts screen: history rows (amount / status
badge / requested + processed dates) + an available-balance banner + a FAB
that opens the request sheet. `PayoutRequestController` (`autoDispose`):
one UUID `Idempotency-Key` per attempt — reused across submit / retry,
new only on `startNewAttempt`; double-submit latched client-side; on
success refreshes payouts + finance and invalidates the dashboard (§12).
The request sheet does client UX validation only (`amount > 0`,
`amount <= availableBalance`) — backend authoritative — and has **no bank
/ account / card fields** (§14). `INSUFFICIENT_AVAILABLE_BALANCE` → a
localized banner + retry with the same key. Real proof (integration test):
a 1.00 payout appears once, the same key twice returns the same payout,
and `available_balance` drops by exactly 1.00. RU/KK/EN parity. Light bg
`#FFFFFF`. No overflow at 360/390/430.

## F6E — Final F6 regression + polish ✅ (complete)
No new seller features — verified the whole seller console as one flow and
fixed only regressions. `test/f6e_seller_regression_test.dart` (25 tests):
every F6 seller string key resolves against the RU keyset; a single local
router walks dashboard → offers → inventory → orders → order detail →
finance → payouts with `takeException() == null` and the light scaffold at
`#FFFFFF`; 18 role-regression cases (anonymous → login, customer → "только
для продавцов", admin → web-only notice, no "Кабинет продавца" chip for a
customer) across all 6 seller routes; a 403 from `/seller/dashboard` →
"Аккаунт продавца недоступен" + exit; a seller with no linked `seller_id`
→ unavailable with no API call; logout clears all 4 seller controllers and
re-login reloads them from the backend; a seller GET survives one 401 →
refresh → retry with no loop. **Polish fix (§13):** all 6 seller
controllers (`dashboard`/`offers`/`inventory`/`orders`/`finance`/`payouts`)
now also reset to their initial state on `AuthStatus.unauthenticated`, so
logout drops seller data from memory — matching the F4 customer pattern.
Integration proof (`backend_integration_test.dart`): a deactivated seller
is `403`/`401` on every `/seller/*` endpoint and reactivation restores
access. Buyer flow untouched (full widget suite green). RU/KK/EN parity,
dark + light `#FFFFFF`, no overflow at 360/390/430.

## F7A — UI / UX polish ✅ (complete)
Presentation-only pass — no new features, no backend changes. New design-
system layer: `core/theme/app_dimens.dart` (`NovaSpace` 4→32, `NovaRadii`
8/10/14/18/pill, `NovaDurations` 150/220/300, `NovaShadows` — soft lift in
light, none in dark, plus a `Gap` widget). `app_theme.dart` gains a named
type hierarchy (display→labelSmall), `FadeForwardsPageTransitionsBuilder`,
dialog/list-tile/tooltip/divider themes, disabled-button colours, a pill
nav indicator (66px), consistent sheet drag-handle. `app.dart` clamps the
OS text scale to 0.9–1.4 so dense layouts stay usable. New shared widgets:
`NovaStateView` (one look for empty/error, soft fade-in) behind the
unchanged `EmptyView`/`ErrorView` APIs; `NovaSkeleton`/`NovaSkeletonList`
(shimmer) replacing every flat-grey `_XSkeleton`; `nova_feedback.dart`
(`NovaSnackbar.success/error/…` + `novaConfirm` destructive dialog);
`NovaSectionLabel` (the uppercase eyebrow, was copy-pasted 4×);
`NovaStickyBar` (shared elevated bottom bar for product/cart/checkout with
one `SafeArea(bottom)` + lift shadow). Screens re-spaced on the tokens,
cards get the soft light-mode shadow + press ripple, product card / order
card / seller cards unified. Snackbars and confirm dialogs routed through
the helpers app-wide. `test/f7a_polish_test.dart` (24 tests): token
sanity, theme invariants (#FFFFFF light, graphite dark, ≥48px buttons),
state views clean in light + dark at textScale 1.0/1.2/1.4, skeletons,
feedback helpers, sticky-bar safe-area, cards no-overflow at large text.
285 widget + 34 integration tests green; APK builds.

## F7B — real Android device verification ✅ (complete)
Ran the app on the `Pixel_6a_API_33` emulator (Android 13, 1080×2400 @
420dpi, headless swiftshader) against `http://10.0.2.2:8081/api/v1`.
Verified on-device: cold start + splash; real-backend login (email
keyboard, `next`/`done` actions, submit stays above the soft keyboard);
home / catalog (2-col grid) / product (gallery dots, offer sheet) /
favorites; cart (add → `NovaSnackbar` green success, qty PATCH, stock
limit, nav badge, `NovaStickyBar`); checkout (auto-selected address card,
payment selector, sticky CTA) → real `POST /me/orders` `201`; order
success (back goes home, never to a resubmittable form) + order detail;
profile (real identity, `_SellerEntry` accent card); seller login →
dashboard (metric cards with emphasized borders) + offers list + FAB;
settings language list + theme switch (dark graphite / light strictly
`#FFFFFF`); filter bottom sheet keeps its CTA above the keyboard; logout
clears favorites/cart in-memory and re-guards `/profile` → login. **Two
device bugs found and fixed:** (1) the product sticky bar truncated
"Купить сейчас" on a 411dp screen — restacked as price line + two
full-width CTAs; (2) home product-rail cards clipped the price at OS font
size 1.3 — the rail (and card) now grow with `MediaQuery.textScaler`.
Zero Flutter exceptions / RenderFlex overflows in logcat across the whole
run. Haptics deferred (can't be validated headless). 285 widget + 34
integration tests green; `flutter analyze` clean; APK builds.

## F7C — iOS / macOS real device verification ⛔ BLOCKED (needs a Mac)
Attempted 2026-09-11 on the Linux host. `flutter doctor` shows **no Xcode
entry at all**; `xcodebuild` / `xcrun` / `pod` / `swift` / `simctl` /
`instruments` are all absent; `flutter build ios` and `flutter build ipa`
**are not even registered subcommands** on a Linux Flutter; `flutter
devices` lists only Linux + Chrome; no Apple USB device. F7C cannot be
run here — it requires macOS + Xcode + CocoaPods + a real iPhone.
No code was changed. The `ios/` project is present and well-formed:
bundle id `kz.nova.novaMarketplace`, `CODE_SIGN_STYLE = Automatic` (no
`DEVELOPMENT_TEAM` set — must be selected in Xcode on the Mac),
`IPHONEOS_DEPLOYMENT_TARGET = 13.0`, `AppDelegate.swift` +
`SceneDelegate.swift`, `UILaunchStoryboardName` launch screen, and an ATS
config that is `NSAllowsArbitraryLoads=false` with a **localhost-only**
`NSExceptionDomains` entry (a code comment already flags: add the Mac LAN
IP for a physical-device dev run, or use HTTPS). `AppEnv.apiBaseUrl`
default is `http://10.0.2.2:8081/api/v1` — an iPhone run MUST override it
with `--dart-define=API_BASE_URL=http://<mac-lan-ip>:8081/api/v1`.
When a Mac is available: `flutter pub get` → `cd ios && pod install` →
open `Runner.xcworkspace`, pick a signing team → `flutter run -d <iphone>
--dart-define=API_BASE_URL=…` and work the §8–§32 checklist.
Project state at block time: `flutter analyze` clean, 285 widget + 34
integration tests green, Android debug APK builds.

## Explicitly out of scope (unless separately requested)
Admin mobile UI · offline-first · push notifications · real payment SDK ·
review submission (needs a new backend endpoint) · product Q&A ·
biometric unlock · deep links beyond basic routing.
