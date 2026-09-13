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
import 'package:nova_marketplace/features/seller/orders/presentation/seller_order_detail_screen.dart';
import 'package:nova_marketplace/features/seller/orders/presentation/seller_orders_screen.dart';
import 'package:nova_marketplace/features/seller/orders/presentation/widgets/seller_order_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/f4_harness.dart';
import 'support/f6a_fixtures.dart';
import 'support/f6c_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

Future<void> _settle(WidgetTester t, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

FakeAuthRepository _seller() => FakeAuthRepository(
  onRefresh: () async => fakeTokens(),
  onMe: () async => fakeUser(role: 'seller', sellerId: 1),
  onLogin: (_) async => AuthSession(
    tokens: fakeTokens(),
    user: fakeUser(role: 'seller', sellerId: 1),
  ),
);

MeBackend _backend() => MeBackend()
  ..on(
    'GET /seller/orders',
    (o) => okList([
      sellerOrderListJson(orderId: 145, sellerItemCount: 1),
      sellerOrderListJson(
        orderId: 144,
        number: 'MK-2026-000144',
        status: 'processing',
        sellerItemCount: 2,
        gross: '900000.00',
        net: '810000.00',
      ),
    ], total: 2),
  )
  ..on(
    'GET /seller/orders/145',
    (o) => ok(
      sellerOrderDetailJson(
        items: [sellerOrderItemJson(name: 'iPhone 17 Pro 256GB', sku: 'IPH-1')],
      ),
    ),
  )
  ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
  ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));

Future<void> _pump(
  WidgetTester tester, {
  required String initial,
  MeBackend? backend,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final client = ApiClient(
    tokenStore: TokenStore(FakeSecureStore()),
    tokenRefresher: const NoopTokenRefresher(),
    dio: Dio()..httpClientAdapter = FakeAdapter((backend ?? _backend()).handle),
  );
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/seller/orders',
        builder: (_, _) => const SellerOrdersScreen(),
      ),
      GoRoute(
        path: '/seller/orders/:orderId',
        builder: (_, s) =>
            SellerOrderDetailScreen(orderId: s.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
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
        authRepositoryProvider.overrideWithValue(_seller()),
        apiClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await _settle(tester);
}

void main() {
  group('SellerOrdersScreen', () {
    testWidgets('cards render number/date/status/amounts, no overflow', (
      tester,
    ) async {
      for (final w in [360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(w, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await _pump(tester, initial: '/seller/orders');
        expect(tester.takeException(), isNull, reason: 'overflow @$w');
        expect(find.byType(SellerOrderCard), findsNWidgets(2));
        expect(find.text('MK-2026-000145'), findsOneWidget);
        expect(find.text('Оплачен'), findsWidgets); // status
        expect(find.text('К зачислению'), findsWidgets); // net label
        // no add/mutation affordance
        expect(find.byType(FloatingActionButton), findsNothing);
      }
    });

    testWidgets('empty state', (tester) async {
      final be = _backend()
        ..on('GET /seller/orders', (o) => okList(const [], total: 0));
      await _pump(tester, initial: '/seller/orders', backend: be);
      expect(find.text('Пока нет заказов'), findsOneWidget);
    });

    testWidgets('error → retry', (tester) async {
      final be = _backend()
        ..on(
          'GET /seller/orders',
          (o) => jsonBody(503, {
            'error': {'code': 'X', 'message': 'down'},
          }),
        );
      await _pump(tester, initial: '/seller/orders', backend: be);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('tap card → detail screen', (tester) async {
      await _pump(tester, initial: '/seller/orders');
      await tester.tap(find.text('MK-2026-000145'));
      await _settle(tester);
      expect(find.byType(SellerOrderDetailScreen), findsOneWidget);
    });
  });

  group('SellerOrderDetailScreen', () {
    testWidgets('shows this seller lines, delivery, totals — no overflow', (
      tester,
    ) async {
      for (final w in [360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(w, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        final be = _backend()
          ..on(
            'GET /seller/orders/145',
            (o) => ok(
              sellerOrderDetailJson(
                items: [
                  sellerOrderItemJson(
                    name: 'iPhone 17 Pro 256GB Космический титан очень длинное',
                    sku: 'SKU-BROWSER-TEST-1788112976175',
                  ),
                  sellerOrderItemJson(
                    name: 'AirPods Pro',
                    sku: 'AP-2',
                    quantity: 2,
                    unitPrice: '90000.00',
                    totalPrice: '180000.00',
                  ),
                ],
                gross: '800000.00',
                net: '720000.00',
              ),
            ),
          );
        await _pump(tester, initial: '/seller/orders/145', backend: be);
        expect(tester.takeException(), isNull, reason: 'overflow @$w');
        expect(find.text('MK-2026-000145'), findsOneWidget);
        expect(find.textContaining('iPhone 17 Pro'), findsWidgets);
        expect(find.text('AirPods Pro'), findsOneWidget);
        expect(find.textContaining('Алматы'), findsWidgets); // delivery
        expect(
          find.text('Показаны только ваши позиции этого заказа'),
          findsOneWidget,
        );
      }
    });

    testWidgets('read-only: no status-changing control', (tester) async {
      await _pump(tester, initial: '/seller/orders/145');
      // no dropdowns, no FAB, no "change status"/action buttons
      expect(find.byType(DropdownButton<Object?>), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      // the only interactive things are the app-bar back button + pull-to-refresh
      final textButtons = find.byType(TextButton);
      expect(textButtons, findsNothing);
    });

    testWidgets('404 → not found', (tester) async {
      final be = _backend()
        ..on('GET /seller/orders/999', (o) => notFoundBody('ORDER_NOT_FOUND'));
      await _pump(tester, initial: '/seller/orders/999', backend: be);
      expect(find.text('Заказ не найден'), findsOneWidget);
    });
  });
}
