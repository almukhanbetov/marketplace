/// Every route path in the app, in one place. Keeps `context.go(...)`
/// calls free of string literals.
class Routes {
  const Routes._();

  // Customer shell tabs
  static const home = '/';
  static const catalog = '/catalog';
  static const favorites = '/favorites';
  static const cart = '/cart';
  static const profile = '/profile';

  // Customer stack routes
  static const login = '/login';
  static const register = '/register';
  static const checkout = '/checkout';
  static const checkoutSuccess = '/checkout/success';
  static const settings = '/settings';
  static const addresses = '/profile/addresses';

  /// Order history lives under the profile branch so the bottom-nav
  /// "Profile" tab stays highlighted while browsing orders.
  static const orders = '/profile/orders';
  static String order(Object id) => '/profile/orders/$id';

  static String product(Object id) => '/product/$id';
  static const productPattern = '/product/:id';

  /// Public seller storefront. Lives under `/seller/:id` (numeric) —
  /// go_router matches the static private routes below (`/seller/dashboard`
  /// …) first, so there is no collision. The route guard whitelists a
  /// numeric `/seller/<id>` as public (Stage F3 §41).
  static String seller(Object id) => '/seller/$id';
  static const sellerPublicPattern = '/seller/:id';
  static final _publicSellerRe = RegExp(r'^/seller/\d+$');
  static bool isPublicSellerPath(String loc) => _publicSellerRe.hasMatch(loc);

  // Seller section (private, auth-gated)
  static const sellerDashboard = '/seller/dashboard';
  static const sellerOffers = '/seller/offers';
  static const sellerOfferNew = '/seller/offers/new';
  static String sellerOfferEdit(Object offerId) =>
      '/seller/offers/$offerId/edit';
  static const sellerInventory = '/seller/inventory';
  static const sellerOrders = '/seller/orders';
  static String sellerOrder(Object orderId) => '/seller/orders/$orderId';
  static const sellerFinance = '/seller/finance';
  static const sellerPayouts = '/seller/payouts';

  /// Admin is intentionally NOT a mobile section — see docs/AUDIT.md §Admin.
  /// This route only shows an "admin is web-only" notice.
  static const adminNotice = '/admin';
}
