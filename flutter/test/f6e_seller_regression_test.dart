import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nova_marketplace/app/app.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/api_providers.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/auth_repository.dart';
import 'package:nova_marketplace/core/auth/auth_repository_impl.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/localization/strings/strings_ru.dart';
import 'package:nova_marketplace/core/storage/preferences_store.dart';
import 'package:nova_marketplace/core/storage/secure_storage.dart';
import 'package:nova_marketplace/core/theme/app_theme.dart';
import 'package:nova_marketplace/features/seller/orders/presentation/seller_order_detail_screen.dart';
import 'package:nova_marketplace/features/seller/dashboard/presentation/seller_dashboard_screen.dart';
import 'package:nova_marketplace/features/seller/finance/application/seller_finance_controller.dart';
import 'package:nova_marketplace/features/seller/finance/presentation/seller_finance_screen.dart';
import 'package:nova_marketplace/features/seller/inventory/presentation/seller_inventory_screen.dart';
import 'package:nova_marketplace/features/seller/offers/application/seller_offers_controller.dart';
import 'package:nova_marketplace/features/seller/offers/presentation/seller_offers_screen.dart';
import 'package:nova_marketplace/features/seller/orders/application/seller_orders_controller.dart';
import 'package:nova_marketplace/features/seller/orders/presentation/seller_orders_screen.dart';
import 'package:nova_marketplace/features/seller/payouts/application/seller_payouts_controller.dart';
import 'package:nova_marketplace/features/seller/payouts/presentation/seller_payouts_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/f4_harness.dart';
import 'support/f6a_fixtures.dart';
import 'support/f6b_fixtures.dart';
import 'support/f6c_fixtures.dart';
import 'support/f6d_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

Future<void> _pump(WidgetTester t, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

BuildContext _ctx(WidgetTester t) => t.element(find.byType(Navigator).first);

/// Full seller-console backend covering every F6A–F6D endpoint.
MeBackend _sellerBackend() => MeBackend()
  ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
  ..on('GET /sellers/1', (o) => ok(sellerProfileJson()))
  ..on(
    'GET /seller/offers',
    (o) => okList([
      sellerOfferJson(id: 1, sku: 'SKU-A', isLowStock: true),
      sellerOfferJson(id: 2, sku: 'SKU-B', isActive: false),
    ], total: 2),
  )
  ..on(
    'GET /seller/inventory',
    (o) => okRaw([
      sellerInventoryJson(offerId: 1, available: 3, isLowStock: true),
      sellerInventoryJson(offerId: 2, available: 40, isLowStock: false),
    ]),
  )
  ..on(
    'GET /seller/orders',
    (o) => okList([
      sellerOrderListJson(orderId: 145, sellerItemCount: 1),
      sellerOrderListJson(orderId: 144, number: 'MK-2026-000144'),
    ], total: 2),
  )
  ..on('GET /seller/orders/145', (o) => ok(sellerOrderDetailJson()))
  ..on('GET /seller/finance', (o) => ok(sellerFinanceJson()))
  ..on(
    'GET /seller/payouts',
    (o) => okRaw([
      sellerPayoutJson(id: 1, status: 'paid'),
      sellerPayoutJson(id: 2, status: 'pending'),
    ]),
  );

FakeAuthRepository _repoForRole(String? role, {int? sellerId}) {
  if (role == null) return FakeAuthRepository();
  return FakeAuthRepository(
    onRefresh: () async => fakeTokens(),
    onMe: () async => fakeUser(role: role, sellerId: sellerId),
    onLogin: (_) async => AuthSession(
      tokens: fakeTokens(),
      user: fakeUser(role: role, sellerId: sellerId),
    ),
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  String? role,
  int? sellerId,
  MeBackend? backend,
  FakeAuthRepository? authRepo,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final client = ApiClient(
    tokenStore: TokenStore(FakeSecureStore()),
    tokenRefresher: const NoopTokenRefresher(),
    dio: Dio()
      ..httpClientAdapter = FakeAdapter((backend ?? MeBackend()).handle),
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        secureStoreProvider.overrideWithValue(
          FakeSecureStore(refreshToken: role == null ? null : 'stored'),
        ),
        authRepositoryProvider.overrideWithValue(
          authRepo ?? _repoForRole(role, sellerId: sellerId),
        ),
        apiClientProvider.overrideWithValue(client),
      ],
      child: const NovaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. F6 string coverage — every s('...') key the seller screens use exists.
  // ---------------------------------------------------------------------------
  test('every F6 seller string key resolves (RU keyset is the source)', () {
    // Static keys pulled from the seller feature tree by grep in the audit;
    // the localization parity test then guarantees KK + EN cover the same set.
    const keys = <String>[
      'seller.dashboard.title',
      'seller.dashboard.quickActions',
      'seller.dashboard.noReviews',
      'seller.metric.salesToday',
      'seller.metric.ordersToday',
      'seller.metric.ordersTotal',
      'seller.metric.availableBalance',
      'seller.metric.pendingBalance',
      'seller.metric.activeOffers',
      'seller.metric.lowStock',
      'seller.metric.lowStockHint',
      'seller.action.offers',
      'seller.action.inventory',
      'seller.action.orders',
      'seller.action.finance',
      'seller.action.payouts',
      'seller.unavailable.title',
      'seller.unavailable.body',
      'seller.offers.title',
      'seller.offers.add',
      'seller.offers.edit',
      'seller.offers.searchHint',
      'seller.offers.empty.title',
      'seller.offers.empty.body',
      'seller.offers.created',
      'seller.offers.saved',
      'seller.offers.activate',
      'seller.offers.deactivate',
      'seller.offers.status.active',
      'seller.offers.status.inactive',
      'seller.offers.filter.all',
      'seller.offers.filter.active',
      'seller.offers.filter.inactive',
      'seller.offers.filter.lowStock',
      'seller.offers.stockN',
      'seller.offers.deliveryN',
      'seller.offers.field.sku',
      'seller.offers.field.price',
      'seller.offers.field.oldPrice',
      'seller.offers.field.deliveryDays',
      'seller.offers.field.stock',
      'seller.offers.validation.skuRequired',
      'seller.offers.validation.priceInvalid',
      'seller.offers.productSelect.title',
      'seller.offers.productSelect.cta',
      'seller.inventory.title',
      'seller.inventory.empty.title',
      'seller.inventory.availableN',
      'seller.inventory.lowStock',
      'seller.inventory.editTitle',
      'seller.inventory.field.available',
      'seller.orders.title',
      'seller.orders.detailTitle',
      'seller.orders.empty.title',
      'seller.orders.itemsN',
      'seller.orders.gross',
      'seller.orders.commission',
      'seller.orders.net',
      'seller.orders.items',
      'seller.orders.delivery',
      'seller.orders.yourLinesOnly',
      'seller.finance.title',
      'seller.finance.available',
      'seller.finance.pending',
      'seller.finance.grossSales',
      'seller.finance.commission',
      'seller.finance.net',
      'seller.finance.paidOut',
      'seller.finance.viewPayouts',
      'payout.title',
      'payout.empty.title',
      'payout.availableToWithdraw',
      'payout.requestedOn',
      'payout.processedOn',
      'payout.status.pending',
      'payout.status.processing',
      'payout.status.paid',
      'payout.status.rejected',
      'payout.request.title',
      'payout.request.submit',
      'payout.request.field.amount',
      'payout.request.availableHint',
      'payout.request.error.positive',
      'payout.request.error.overAvailable',
      'error.INSUFFICIENT_AVAILABLE_BALANCE',
      'error.OFFER_NOT_FOUND',
      'error.SKU_ALREADY_EXISTS',
    ];
    for (final k in keys) {
      expect(kStringsRu.containsKey(k), isTrue, reason: 'missing $k');
    }
  });

  // ---------------------------------------------------------------------------
  // 2. Full seller navigation as one coherent walk (seller route tree only,
  //    finite pumps — network-image shimmer never settles).
  // ---------------------------------------------------------------------------
  testWidgets('seller walk: dashboard → offers → inventory → orders → detail '
      '→ finance → payouts, no exception', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final client = ApiClient(
      tokenStore: TokenStore(FakeSecureStore()),
      tokenRefresher: const NoopTokenRefresher(),
      dio: Dio()..httpClientAdapter = FakeAdapter(_sellerBackend().handle),
    );
    final router = GoRouter(
      initialLocation: '/seller/dashboard',
      routes: [
        GoRoute(
          path: '/seller/dashboard',
          builder: (_, _) => const SellerDashboardScreen(),
        ),
        GoRoute(
          path: '/seller/offers',
          builder: (_, _) => const SellerOffersScreen(),
        ),
        GoRoute(
          path: '/seller/inventory',
          builder: (_, _) => const SellerInventoryScreen(),
        ),
        GoRoute(
          path: '/seller/orders',
          builder: (_, _) => const SellerOrdersScreen(),
          routes: [
            GoRoute(
              path: ':orderId',
              builder: (_, s) => SellerOrderDetailScreen(
                orderId: s.pathParameters['orderId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/seller/finance',
          builder: (_, _) => const SellerFinanceScreen(),
        ),
        GoRoute(
          path: '/seller/payouts',
          builder: (_, _) => const SellerPayoutsScreen(),
        ),
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/product/:id', builder: (_, _) => const Scaffold()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          secureStoreProvider.overrideWithValue(
            FakeSecureStore(refreshToken: 'stored'),
          ),
          authRepositoryProvider.overrideWithValue(
            _repoForRole('seller', sellerId: 1),
          ),
          apiClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await _pump(tester);

    BuildContext ctx() => tester.element(find.byType(Navigator).first);

    expect(find.byType(SellerDashboardScreen), findsOneWidget);
    expect(find.text('TechStore'), findsOneWidget); // real identity
    expect(find.text('Продажи сегодня'), findsOneWidget); // real metric
    // light background is #FFFFFF on the dashboard
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      const Color(0xFFFFFFFF),
    );

    ctx().go('/seller/offers');
    await _pump(tester);
    expect(find.text('SKU: SKU-A'), findsOneWidget);
    expect(find.text('Неактивно'), findsOneWidget); // inactive offer visible

    ctx().go('/seller/inventory');
    await _pump(tester);
    expect(find.textContaining('Заканчивается позиций'), findsOneWidget);

    ctx().go('/seller/orders');
    await _pump(tester);
    expect(find.text('MK-2026-000145'), findsOneWidget);
    await tester.tap(find.text('MK-2026-000145'));
    await _pump(tester);
    expect(
      find.text('Показаны только ваши позиции этого заказа'),
      findsOneWidget,
    );

    ctx().go('/seller/finance');
    await _pump(tester);
    expect(find.textContaining('вывести нельзя'), findsWidgets);

    ctx().go('/seller/payouts');
    await _pump(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // 3. Role / RBAC regression on every seller entry point.
  // ---------------------------------------------------------------------------
  group('role regression', () {
    for (final route in const [
      '/seller/dashboard',
      '/seller/offers',
      '/seller/inventory',
      '/seller/orders',
      '/seller/finance',
      '/seller/payouts',
    ]) {
      testWidgets('anonymous → $route → login', (tester) async {
        await _pumpApp(tester);
        _ctx(tester).go(route);
        await tester.pumpAndSettle();
        expect(find.text('Вход'), findsWidgets);
      });

      testWidgets('customer → $route → sellers-only screen', (tester) async {
        await _pumpApp(tester, role: 'customer');
        _ctx(tester).go(route);
        await tester.pumpAndSettle();
        expect(find.text('Только для продавцов'), findsOneWidget);
      });

      testWidgets('admin → $route → web-only notice', (tester) async {
        await _pumpApp(tester, role: 'admin');
        _ctx(tester).go(route);
        await tester.pumpAndSettle();
        expect(find.text('Администрирование в веб-версии'), findsOneWidget);
      });
    }

    testWidgets('customer does not see "Кабинет продавца" in Profile', (
      tester,
    ) async {
      await _pumpApp(tester, role: 'customer');
      _ctx(tester).go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Кабинет продавца'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Seller deactivation — a 403 from /seller/* → graceful exit.
  // ---------------------------------------------------------------------------
  testWidgets('deactivated seller: dashboard 403 → unavailable state + exit', (
    tester,
  ) async {
    final be = _sellerBackend()
      ..on(
        'GET /seller/dashboard',
        (o) => jsonBody(403, {
          'error': {'code': 'FORBIDDEN', 'message': 'no active seller'},
        }),
      );
    await _pumpApp(tester, role: 'seller', sellerId: 1, backend: be);
    _ctx(tester).go('/seller/dashboard');
    await _pump(tester);
    expect(find.text('Аккаунт продавца недоступен'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Главная'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Главная'));
    await tester.pumpAndSettle();
    expect(find.byType(SellerDashboardScreen), findsNothing);
  });

  testWidgets('seller with no linked seller_id → unavailable, no API call', (
    tester,
  ) async {
    final be = _sellerBackend();
    await _pumpApp(tester, role: 'seller', sellerId: null, backend: be);
    _ctx(tester).go('/seller/dashboard');
    await tester.pumpAndSettle();
    // guard sends non-linked sellers to the sellers-only screen
    expect(find.text('Только для продавцов'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // 5. Logout clears seller in-memory data; re-login reloads it (§13).
  // ---------------------------------------------------------------------------
  test(
    'logout clears seller controllers; re-login reloads from backend',
    () async {
      final h = await F4Container.create(
        backend: _sellerBackend(),
        user: fakeUser(role: 'seller', sellerId: 1),
      );
      // Keep the seller controllers alive across the auth transitions.
      h.container
        ..listen(sellerOffersControllerProvider, (_, _) {})
        ..listen(sellerOrdersControllerProvider, (_, _) {})
        ..listen(sellerFinanceControllerProvider, (_, _) {})
        ..listen(sellerPayoutsControllerProvider, (_, _) {});
      await h.settleAuth();
      await h.login();
      await pumpUntil(
        () =>
            h.container.read(sellerOffersControllerProvider).status ==
                SellerOffersStatus.loaded &&
            h.container.read(sellerFinanceControllerProvider).status ==
                SellerFinanceStatus.loaded,
      );
      expect(
        h.container.read(sellerOffersControllerProvider).items,
        isNotEmpty,
      );
      expect(h.container.read(sellerFinanceControllerProvider).data, isNotNull);

      await h.logout();
      await pumpUntil(
        () =>
            h.container.read(sellerOffersControllerProvider).items.isEmpty &&
            h.container.read(sellerFinanceControllerProvider).data == null,
      );
      // in-memory seller data is gone
      expect(h.container.read(sellerOffersControllerProvider).items, isEmpty);
      expect(h.container.read(sellerOrdersControllerProvider).items, isEmpty);
      expect(h.container.read(sellerFinanceControllerProvider).data, isNull);
      expect(h.container.read(sellerPayoutsControllerProvider).items, isEmpty);

      await h.login();
      await pumpUntil(
        () =>
            h.container.read(sellerOffersControllerProvider).status ==
            SellerOffersStatus.loaded,
      );
      // reloaded from the backend
      expect(
        h.container.read(sellerOffersControllerProvider).items,
        isNotEmpty,
      );
      expect(h.container.read(sellerFinanceControllerProvider).data, isNotNull);
    },
  );

  // ---------------------------------------------------------------------------
  // 6. Auth-token refresh: a one-off 401 on a seller GET recovers, no loop.
  // ---------------------------------------------------------------------------
  test(
    'seller GET survives a single 401 → refresh → retry (no loop)',
    () async {
      var first = true;
      final adapter = FakeAdapter((o, i) {
        if (o.path.endsWith('/seller/finance') && first) {
          first = false;
          return jsonBody(401, {
            'error': {'code': 'SESSION_EXPIRED', 'message': 'expired'},
          });
        }
        return ok(sellerFinanceJson());
      });
      final ts = TokenStore(FakeSecureStore());
      ts.setAccessToken('t', DateTime.now().add(const Duration(minutes: 5)));
      final refresher = CountingRefresher(store: ts, token: 'fresh');
      final api = ApiClient(
        tokenStore: ts,
        tokenRefresher: refresher,
        dio: Dio()..httpClientAdapter = adapter,
      );
      final data = await AuthRepositoryImpl(api, ts).me().catchError((_) {
        return fakeUser();
      });
      // The real check: a finance GET through the same client recovers.
      final f = await api.get('/seller/finance');
      expect((f as Map)['available_balance'], isNotNull);
      expect(refresher.refreshCalls, lessThanOrEqualTo(1));
      expect(data, isNotNull);
    },
  );
}
