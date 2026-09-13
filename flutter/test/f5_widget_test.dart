import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/api_providers.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/auth_repository.dart';
import 'package:nova_marketplace/core/auth/auth_repository_impl.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/storage/preferences_store.dart';
import 'package:nova_marketplace/core/storage/secure_storage.dart';
import 'package:nova_marketplace/core/theme/app_theme.dart';
import 'package:nova_marketplace/features/checkout/presentation/checkout_screen.dart';
import 'package:nova_marketplace/features/orders/data/order_models.dart';
import 'package:nova_marketplace/features/orders/presentation/order_detail_screen.dart';
import 'package:nova_marketplace/features/orders/presentation/order_success_screen.dart';
import 'package:nova_marketplace/features/orders/presentation/orders_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/f4_fixtures.dart';
import 'support/f4_harness.dart';
import 'support/f5_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

Future<void> _settle(WidgetTester t, {int frames = 45}) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

FakeAuthRepository _customer() => FakeAuthRepository(
  onRefresh: () async => fakeTokens(),
  onMe: () async => fakeUser(role: 'customer'),
  onLogin: (_) async => AuthSession(
    tokens: fakeTokens(),
    user: fakeUser(role: 'customer'),
  ),
);

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String initialPath,
  required MeBackend backend,
  Object? extra,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final client = ApiClient(
    tokenStore: TokenStore(FakeSecureStore()),
    tokenRefresher: const NoopTokenRefresher(),
    dio: Dio()..httpClientAdapter = FakeAdapter(backend.handle),
  );
  final router = GoRouter(
    initialLocation: initialPath,
    routes: [
      GoRoute(
        path: '/checkout',
        builder: (_, _) => const CheckoutScreen(),
        routes: [
          GoRoute(
            path: 'success',
            builder: (_, s) =>
                OrderSuccessScreen(result: s.extra as CreateOrderResult?),
          ),
        ],
      ),
      GoRoute(path: '/profile/orders', builder: (_, _) => const OrdersScreen()),
      // Flat (not nested) so OrdersScreen isn't also built underneath — the
      // real router pushes this on the root navigator for the same reason.
      GoRoute(
        path: '/profile/orders/:id',
        builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/cart',
        builder: (_, _) => const Scaffold(body: Text('CART SCREEN')),
      ),
      GoRoute(
        path: '/catalog',
        builder: (_, _) => const Scaffold(body: Text('CATALOG')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
      GoRoute(
        path: '/profile/addresses',
        builder: (_, _) => const Scaffold(body: Text('ADDR')),
      ),
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
        authRepositoryProvider.overrideWithValue(_customer()),
        apiClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await _settle(tester);
  if (extra != null) {
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).go(initialPath, extra: extra);
    await _settle(tester);
  }
  return router;
}

MeBackend _checkoutBackend({
  ResponseBody Function(RequestOptions o)? order,
  bool emptyCart = false,
  List<Map<String, dynamic>>? addresses,
}) {
  return MeBackend()
    ..on(
      'GET /me/cart',
      (o) => emptyCart
          ? ok(cartJson())
          : ok(
              cartJson(
                items: [
                  cartItemJson(
                    id: 1,
                    sellerOfferId: 1,
                    sellerName: 'TechStore',
                  ),
                  cartItemJson(
                    id: 2,
                    sellerOfferId: 4,
                    sellerId: 4,
                    sellerName: 'GadgetPro',
                  ),
                ],
                itemCount: 2,
                subtotal: '1160000.00',
              ),
            ),
    )
    ..on(
      'GET /me/addresses',
      (o) => okRaw(addresses ?? [addressJson(id: 50, isDefault: true)]),
    )
    ..on('GET /me/orders', (o) => okRaw(const []))
    ..on(
      'POST /me/orders',
      order ?? (o) => jsonBody(201, {'data': orderDetailJson()}),
    );
}

void main() {
  testWidgets('checkout: empty cart shows empty state, no order POST (§7)', (
    tester,
  ) async {
    final be = _checkoutBackend(emptyCart: true);
    await _pump(tester, initialPath: '/checkout', backend: be);
    expect(find.text('Корзина пуста'), findsOneWidget);
    expect(be.countOf('POST', '/me/orders'), 0);
  });

  testWidgets('checkout: form renders all sections, no overflow (§58)', (
    tester,
  ) async {
    for (final w in [360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(w, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(
        tester,
        initialPath: '/checkout',
        backend: _checkoutBackend(),
      );
      expect(tester.takeException(), isNull, reason: 'overflow @$w');
      expect(find.text('TechStore'), findsWidgets);
      expect(find.text('GadgetPro'), findsWidgets);
      expect(find.text('Банковская карта'), findsOneWidget);
      expect(find.text('Kaspi'), findsOneWidget);
      expect(find.textContaining('списание не производится'), findsOneWidget);
      // default address auto-selected → place-order button enabled
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Оформить заказ'),
      );
      expect(btn.onPressed, isNotNull);
    }
  });

  testWidgets('checkout: place order → success screen with order number', (
    tester,
  ) async {
    final be = _checkoutBackend();
    await _pump(tester, initialPath: '/checkout', backend: be);

    await tester.tap(find.widgetWithText(FilledButton, 'Оформить заказ'));
    await _settle(tester);

    expect(be.countOf('POST', '/me/orders'), 1);
    expect(find.text('Заказ оформлен'), findsWidgets);
    expect(find.text('MK-2026-000197'), findsOneWidget);
    // back must not return to a resubmittable checkout
    expect(find.byType(CheckoutScreen), findsNothing);
  });

  testWidgets('checkout: INSUFFICIENT_STOCK shows banner + back-to-cart', (
    tester,
  ) async {
    final be = _checkoutBackend(
      order: (o) => jsonBody(409, {
        'error': {'code': 'INSUFFICIENT_STOCK', 'message': 'x'},
      }),
    );
    await _pump(tester, initialPath: '/checkout', backend: be);
    await tester.tap(find.widgetWithText(FilledButton, 'Оформить заказ'));
    await _settle(tester);

    expect(find.textContaining('Недостаточно товара'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Вернуться в корзину'),
      findsOneWidget,
    );
    // CTA becomes a retry
    expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);
  });

  testWidgets('checkout: no address → add-address CTA', (tester) async {
    final be = _checkoutBackend(addresses: const []);
    await _pump(tester, initialPath: '/checkout', backend: be);
    expect(find.text('Нет адреса доставки'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Добавить адрес'), findsOneWidget);
    // can't place an order without an address
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Оформить заказ'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('orders list renders cards; tap opens detail', (tester) async {
    final be = MeBackend()
      ..on(
        'GET /me/orders',
        (o) => okRaw([
          orderListItemJson(id: 197, number: 'MK-2026-000197'),
          orderListItemJson(id: 5, number: 'MK-2026-000005'),
        ]),
      )
      ..on('GET /me/orders/197', (o) => ok(orderDetailJson(id: 197)));
    await _pump(tester, initialPath: '/profile/orders', backend: be);
    expect(find.text('MK-2026-000197'), findsOneWidget);
    expect(find.text('MK-2026-000005'), findsOneWidget);

    await tester.tap(find.text('MK-2026-000197'));
    await _settle(tester);
    expect(find.byType(OrderDetailScreen), findsOneWidget);
  });

  testWidgets('orders list: empty state', (tester) async {
    final be = MeBackend()..on('GET /me/orders', (o) => okRaw(const []));
    await _pump(tester, initialPath: '/profile/orders', backend: be);
    expect(find.text('Заказов пока нет'), findsOneWidget);
  });

  testWidgets('order detail: multi-seller groups + address snapshot, no '
      'overflow (§40/§58)', (tester) async {
    for (final w in [360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(w, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final be = MeBackend()
        ..on(
          'GET /me/orders/197',
          (o) => ok(orderDetailJson(id: 197, multiSeller: true)),
        );
      await _pump(tester, initialPath: '/profile/orders/197', backend: be);
      expect(tester.takeException(), isNull, reason: 'overflow @$w');
      expect(find.text('MK-2026-000197'), findsOneWidget);
      expect(find.text('TechStore'), findsWidgets);
      expect(find.text('HomeComfort'), findsWidgets);
      expect(find.text('GadgetPro'), findsWidgets);
      expect(find.textContaining('Алматы'), findsWidgets); // address snapshot
      expect(find.text('Kaspi'), findsWidgets); // payment
    }
  });

  testWidgets('order detail: 404 → not found', (tester) async {
    final be = MeBackend()
      ..on('GET /me/orders/999', (o) => notFoundBody('ORDER_NOT_FOUND'));
    await _pump(tester, initialPath: '/profile/orders/999', backend: be);
    expect(find.text('Заказ не найден'), findsOneWidget);
  });
}
