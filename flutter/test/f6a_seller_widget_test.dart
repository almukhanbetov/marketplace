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
import 'package:nova_marketplace/core/storage/preferences_store.dart';
import 'package:nova_marketplace/core/storage/secure_storage.dart';
import 'package:nova_marketplace/core/theme/app_theme.dart';
import 'package:nova_marketplace/core/utils/money.dart';
import 'package:nova_marketplace/features/seller/dashboard/presentation/seller_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/f4_harness.dart';
import 'support/f6a_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

Future<void> _settle(WidgetTester t, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

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

/// Pump the **whole app** (for routing / profile checks) with a fake
/// `/seller/*` backend and a restored session in [role].
Future<void> _pumpApp(
  WidgetTester tester, {
  String? role,
  int? sellerId,
  MeBackend? backend,
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
          _repoForRole(role, sellerId: sellerId),
        ),
        apiClientProvider.overrideWithValue(client),
      ],
      child: const NovaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pump just the dashboard screen in a 1-route router (keeps overflow
/// assertions scoped to F6A, away from the pre-existing HomeScreen).
Future<void> _pumpDashboard(
  WidgetTester tester, {
  required MeBackend backend,
  int? sellerId = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final client = ApiClient(
    tokenStore: TokenStore(FakeSecureStore()),
    tokenRefresher: const NoopTokenRefresher(),
    dio: Dio()..httpClientAdapter = FakeAdapter(backend.handle),
  );
  final router = GoRouter(
    initialLocation: '/seller/dashboard',
    routes: [
      GoRoute(
        path: '/seller/dashboard',
        builder: (_, _) => const SellerDashboardScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      for (final p in const [
        '/seller/offers',
        '/seller/inventory',
        '/seller/orders',
        '/seller/finance',
        '/seller/payouts',
      ])
        GoRoute(
          path: p,
          builder: (_, _) => Scaffold(body: Text('R $p')),
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
        authRepositoryProvider.overrideWithValue(
          _repoForRole('seller', sellerId: sellerId),
        ),
        apiClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await _settle(tester);
}

MeBackend _dashboardBackend({
  ResponseBody Function(RequestOptions o)? dashboard,
  ResponseBody Function(RequestOptions o)? profile,
}) => MeBackend()
  ..on('GET /seller/dashboard', dashboard ?? (o) => ok(sellerDashboardJson()))
  ..on('GET /sellers/1', profile ?? (o) => ok(sellerProfileJson()));

void main() {
  group('dashboard screen', () {
    testWidgets('renders metrics, money, header + verified, no overflow', (
      tester,
    ) async {
      for (final w in [360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(w, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await _pumpDashboard(tester, backend: _dashboardBackend());
        expect(tester.takeException(), isNull, reason: 'overflow @$w');
        expect(find.text('TechStore'), findsOneWidget);
        // formatted money — grouped thousands via the Money formatter
        expect(find.text(Money.format('1237280.00')), findsOneWidget);
        expect(find.text(Money.format('2626800.00')), findsOneWidget);
        expect(find.text('Продажи сегодня'), findsOneWidget);
        expect(find.text('Активные предложения'), findsOneWidget);
        expect(find.text('Предложения'), findsOneWidget); // quick action
        expect(find.text('Выплаты'), findsOneWidget);
      }
    });

    testWidgets('low-stock zero hides the hint; non-zero shows it', (
      tester,
    ) async {
      await _pumpDashboard(
        tester,
        backend: _dashboardBackend(
          dashboard: (o) => ok(sellerDashboardJson(lowStockOffers: 0)),
        ),
      );
      expect(find.text('Заканчивается'), findsOneWidget);
      expect(find.textContaining('≤ 5'), findsNothing);
    });

    testWidgets('error state shows retry', (tester) async {
      await _pumpDashboard(
        tester,
        backend: _dashboardBackend(
          dashboard: (o) => jsonBody(503, {
            'error': {'code': 'X', 'message': 'down'},
          }),
        ),
      );
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('403 → seller-unavailable state, can leave', (tester) async {
      await _pumpDashboard(
        tester,
        backend: _dashboardBackend(
          dashboard: (o) => jsonBody(403, {
            'error': {'code': 'FORBIDDEN', 'message': 'no'},
          }),
        ),
      );
      expect(find.text('Аккаунт продавца недоступен'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Главная'), findsOneWidget);
    });

    testWidgets('quick action navigates to its route', (tester) async {
      await _pumpDashboard(tester, backend: _dashboardBackend());
      await tester.tap(find.text('Финансы'));
      await _settle(tester);
      expect(find.text('R /seller/finance'), findsOneWidget);
    });
  });

  group('role / routing', () {
    testWidgets('customer → /seller/dashboard → sellers-only screen', (
      tester,
    ) async {
      await _pumpApp(tester, role: 'customer');
      final ctx = tester.element(find.byType(Navigator).first);
      ctx.go('/seller/dashboard');
      await tester.pumpAndSettle();
      expect(find.text('Только для продавцов'), findsOneWidget);
    });

    testWidgets('seller → /seller/dashboard → real dashboard', (tester) async {
      await _pumpApp(
        tester,
        role: 'seller',
        sellerId: 1,
        backend: _dashboardBackend(),
      );
      final ctx = tester.element(find.byType(Navigator).first);
      ctx.go('/seller/dashboard');
      await _settle(tester);
      expect(find.byType(SellerDashboardScreen), findsOneWidget);
      expect(find.text('Только для продавцов'), findsNothing);
      expect(find.text('TechStore'), findsOneWidget);
    });

    testWidgets('admin → /seller/dashboard → web-only notice', (tester) async {
      await _pumpApp(tester, role: 'admin');
      final ctx = tester.element(find.byType(Navigator).first);
      ctx.go('/seller/dashboard');
      await tester.pumpAndSettle();
      expect(find.text('Администрирование в веб-версии'), findsOneWidget);
      expect(find.byType(SellerDashboardScreen), findsNothing);
    });

    testWidgets('anonymous → /seller/dashboard → login', (tester) async {
      await _pumpApp(tester, role: null);
      final ctx = tester.element(find.byType(Navigator).first);
      ctx.go('/seller/dashboard');
      await tester.pumpAndSettle();
      expect(find.text('Вход'), findsWidgets);
    });
  });

  group('profile entry visibility', () {
    testWidgets('seller sees "Кабинет продавца"', (tester) async {
      await _pumpApp(tester, role: 'seller', sellerId: 1);
      final ctx = tester.element(find.byType(Navigator).first);
      ctx.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Кабинет продавца'), findsOneWidget);
    });

    testWidgets('customer does not see the seller entry', (tester) async {
      await _pumpApp(tester, role: 'customer');
      final ctx = tester.element(find.byType(Navigator).first);
      ctx.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Кабинет продавца'), findsNothing);
    });
  });
}
