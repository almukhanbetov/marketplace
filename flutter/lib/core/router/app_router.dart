import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/addresses/presentation/addresses_screen.dart';
import '../../features/admin/presentation/admin_notice_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/data/order_models.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/order_success_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/product/presentation/product_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/seller/dashboard/presentation/seller_dashboard_screen.dart';
import '../../features/seller/inventory/presentation/seller_inventory_screen.dart';
import '../../features/seller/offers/data/seller_offer_models.dart';
import '../../features/seller/offers/presentation/add_offer_screen.dart';
import '../../features/seller/offers/presentation/edit_offer_screen.dart';
import '../../features/seller/finance/presentation/seller_finance_screen.dart';
import '../../features/seller/offers/presentation/seller_offers_screen.dart';
import '../../features/seller/orders/presentation/seller_order_detail_screen.dart';
import '../../features/seller/orders/presentation/seller_orders_screen.dart';
import '../../features/seller/payouts/presentation/seller_payouts_screen.dart';
import '../../features/seller/presentation/seller_forbidden_screen.dart';
import '../../features/seller/presentation/seller_public_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/nova_splash.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Route guards are LIVE in F2. The backend RBAC is still the real
/// security boundary — these redirects are UX (Stage F2 §35/§36).
const bool kEnableRouteGuards = true;

/// Where the user was headed before session-restore / a guard intercepted
/// them. Consumed once, when restore finishes or after login.
String? _pendingDestination;

const _splash = '/splash';
const _sellerForbidden = '/forbidden/seller';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: _splash,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NovaSplash(),
      ),
      GoRoute(
        path: _sellerForbidden,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerForbiddenScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'product/:id',
                    parentNavigatorKey: _rootKey,
                    builder: (_, s) =>
                        ProductScreen(productId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.catalog,
                builder: (_, _) => const CatalogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.favorites,
                builder: (_, _) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.cart, builder: (_, _) => const CartScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'addresses',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const AddressesScreen(),
                  ),
                  GoRoute(
                    path: 'orders',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const OrdersScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: _rootKey,
                        builder: (_, s) =>
                            OrderDetailScreen(orderId: s.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Full-screen checkout on the root navigator — no bottom nav while
      // the user is committing to an order (Stage F5 §6/§8).
      GoRoute(
        path: Routes.checkout,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const CheckoutScreen(),
        routes: [
          GoRoute(
            path: 'success',
            parentNavigatorKey: _rootKey,
            builder: (_, s) =>
                OrderSuccessScreen(result: s.extra as CreateOrderResult?),
          ),
        ],
      ),

      GoRoute(
        path: Routes.login,
        parentNavigatorKey: _rootKey,
        builder: (_, s) => LoginScreen(returnTo: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.register,
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            RegisterScreen(returnTo: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.adminNotice,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AdminNoticeScreen(),
      ),

      GoRoute(
        path: Routes.sellerDashboard,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerDashboardScreen(),
      ),
      GoRoute(
        path: Routes.sellerOffers,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerOffersScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootKey,
            builder: (_, _) => const AddOfferScreen(),
          ),
          GoRoute(
            path: ':offerId/edit',
            parentNavigatorKey: _rootKey,
            builder: (_, s) => EditOfferScreen(
              offer: s.extra is SellerOfferModel
                  ? s.extra! as SellerOfferModel
                  : null,
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.sellerInventory,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerInventoryScreen(),
      ),
      GoRoute(
        path: Routes.sellerOrders,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerOrdersScreen(),
        routes: [
          GoRoute(
            path: ':orderId',
            parentNavigatorKey: _rootKey,
            builder: (_, s) =>
                SellerOrderDetailScreen(orderId: s.pathParameters['orderId']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.sellerFinance,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerFinanceScreen(),
      ),
      GoRoute(
        path: Routes.sellerPayouts,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerPayoutsScreen(),
      ),

      // Public seller storefront — declared AFTER the static /seller/*
      // routes so `/seller/dashboard` etc. never match `:id`.
      GoRoute(
        path: Routes.sellerPublicPattern,
        parentNavigatorKey: _rootKey,
        builder: (_, s) => SellerPublicScreen(
          sellerId: int.tryParse(s.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
    ],
  );
});

const _protectedPrefixes = <String>[
  Routes.favorites,
  Routes.cart,
  Routes.checkout,
  Routes.profile,
  Routes.orders,
  '/seller',
];

String? _redirect(Ref ref, GoRouterState state) {
  if (!kEnableRouteGuards) return null;

  final auth = ref.read(authControllerProvider);
  final loc = state.matchedLocation;

  // Session still resolving: park on the splash, remember the target.
  if (auth.isResolving) {
    if (loc == _splash) return null;
    _pendingDestination = loc;
    return _splash;
  }

  // Resolved. If we're stuck on the splash, leave for the intended place.
  if (loc == _splash) {
    final dest = _pendingDestination ?? Routes.home;
    _pendingDestination = null;
    return _guard(dest, auth) ?? dest;
  }

  return _guard(loc, auth);
}

/// The access rules. Returns a redirect target, or null to allow.
String? _guard(String loc, AuthState auth) {
  // Public seller storefront (`/seller/<numeric>`) — anonymous is fine.
  if (Routes.isPublicSellerPath(loc)) return null;

  final authed = auth.isAuthenticated;
  final user = auth.user;
  final atAuthScreen = loc == Routes.login || loc == Routes.register;
  final isSellerRoute = loc.startsWith('/seller/');
  final needsAuth = !atAuthScreen && _protectedPrefixes.any(loc.startsWith);

  if (atAuthScreen) {
    if (authed) {
      return user?.isAdmin == true ? Routes.adminNotice : Routes.home;
    }
    return null;
  }

  if (!authed && (needsAuth || loc == Routes.adminNotice)) {
    return '${Routes.login}?from=${Uri.encodeComponent(loc)}';
  }

  if (loc == Routes.adminNotice) return null; // any authed user may see it

  // Admin is web-only on mobile — bounce them to the notice from anywhere
  // that isn't the notice itself (customer shell OR a seller route).
  if (authed &&
      user?.isAdmin == true &&
      (isSellerRoute || _isCustomerShellRoute(loc))) {
    return Routes.adminNotice;
  }

  if (isSellerRoute && authed && user?.hasSellerAccount != true) {
    return _sellerForbidden;
  }

  return null;
}

bool _isCustomerShellRoute(String loc) =>
    loc == Routes.home ||
    loc.startsWith(Routes.catalog) ||
    loc.startsWith(Routes.favorites) ||
    loc.startsWith(Routes.cart) ||
    loc.startsWith(Routes.profile);

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _sub = ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
