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
import 'package:nova_marketplace/features/seller/finance/presentation/seller_finance_screen.dart';
import 'package:nova_marketplace/features/seller/payouts/presentation/seller_payouts_screen.dart';
import 'package:nova_marketplace/shared/widgets/nova_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/f4_harness.dart';
import 'support/f6a_fixtures.dart';
import 'support/f6d_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

Future<void> _settle(WidgetTester t, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(NovaTextField)),
  matching: find.byType(TextField),
);

FakeAuthRepository _seller() => FakeAuthRepository(
  onRefresh: () async => fakeTokens(),
  onMe: () async => fakeUser(role: 'seller', sellerId: 1),
  onLogin: (_) async => AuthSession(
    tokens: fakeTokens(),
    user: fakeUser(role: 'seller', sellerId: 1),
  ),
);

MeBackend _backend({
  String available = '2626800.00',
  List<Map<String, dynamic>>? payouts,
  ResponseBody Function(RequestOptions o)? createPayout,
}) => MeBackend()
  ..on(
    'GET /seller/finance',
    (o) => ok(sellerFinanceJson(availableBalance: available)),
  )
  ..on(
    'GET /seller/payouts',
    (o) => okRaw(
      payouts ??
          [
            sellerPayoutJson(
              id: 3,
              amount: '900.00',
              status: 'rejected',
              processedAt: '2026-08-31T00:00:06.9+05:00',
            ),
            sellerPayoutJson(
              id: 2,
              amount: '1200.00',
              status: 'paid',
              processedAt: '2026-08-31T00:00:06.0+05:00',
            ),
            sellerPayoutJson(id: 1, amount: '50000.00', status: 'pending'),
          ],
    ),
  )
  ..on(
    'POST /seller/payouts',
    createPayout ??
        (o) => jsonBody(201, {
          'data': sellerPayoutJson(id: 900, amount: '100.00'),
        }),
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
        path: '/seller/finance',
        builder: (_, _) => const SellerFinanceScreen(),
      ),
      GoRoute(
        path: '/seller/payouts',
        builder: (_, _) => const SellerPayoutsScreen(),
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
  group('SellerFinanceScreen', () {
    testWidgets('shows all figures + available/pending distinction, no '
        'overflow', (tester) async {
      for (final w in [360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(w, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await _pump(tester, initial: '/seller/finance');
        expect(tester.takeException(), isNull, reason: 'overflow @$w');
        expect(find.text('Доступно к выводу'), findsWidgets);
        expect(find.text('В ожидании'), findsOneWidget);
        expect(find.textContaining('вывести нельзя'), findsWidgets);
        expect(find.text('Продажи (брутто)'), findsOneWidget);
        expect(find.text('Комиссия маркетплейса'), findsOneWidget);
        expect(find.text('Выведено всего'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Запросить выплату'),
          findsOneWidget,
        );
      }
    });
  });

  group('SellerPayoutsScreen', () {
    testWidgets('lists payouts with status + dates, FAB present, no overflow', (
      tester,
    ) async {
      for (final w in [360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(w, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await _pump(tester, initial: '/seller/payouts');
        expect(tester.takeException(), isNull, reason: 'overflow @$w');
        expect(find.text('Выплачено'), findsOneWidget);
        expect(find.text('Отклонено'), findsOneWidget);
        expect(find.text('Ожидает'), findsOneWidget);
        expect(find.textContaining('Запрошено'), findsWidgets);
        expect(find.textContaining('Обработано'), findsWidgets);
        expect(find.byType(FloatingActionButton), findsOneWidget);
      }
    });

    testWidgets('empty state', (tester) async {
      await _pump(
        tester,
        initial: '/seller/payouts',
        backend: _backend(payouts: const []),
      );
      expect(find.text('Выплат пока нет'), findsOneWidget);
    });
  });

  group('RequestPayoutSheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await _pump(tester, initial: '/seller/payouts');
      await tester.tap(find.byType(FloatingActionButton));
      await _settle(tester);
    }

    testWidgets('zero / negative / over-available rejected client-side', (
      tester,
    ) async {
      await openSheet(tester);
      expect(find.text('Запросить выплату'), findsWidgets);

      await tester.enterText(_field('Сумма, ₸'), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Запросить'));
      await tester.pump();
      expect(find.text('Введите сумму больше нуля'), findsOneWidget);

      await tester.enterText(_field('Сумма, ₸'), '99999999');
      await tester.tap(find.widgetWithText(FilledButton, 'Запросить'));
      await tester.pump();
      expect(find.text('Сумма превышает доступный баланс'), findsOneWidget);
    });

    testWidgets('valid submit → POST, sheet closes, snackbar', (tester) async {
      await _pump(tester, initial: '/seller/payouts');
      final be = _backend();
      // re-pump with a backend we can inspect
      await _pump(tester, initial: '/seller/payouts', backend: be);
      await tester.tap(find.byType(FloatingActionButton));
      await _settle(tester);
      await tester.enterText(_field('Сумма, ₸'), '100');
      await tester.tap(find.widgetWithText(FilledButton, 'Запросить'));
      await _settle(tester);
      expect(be.countOf('POST', '/seller/payouts'), 1);
      expect(find.text('Сумма, ₸'), findsNothing); // sheet closed
      expect(find.text('Запрос на выплату отправлен'), findsOneWidget);
    });

    testWidgets('backend INSUFFICIENT_AVAILABLE_BALANCE → localized banner', (
      tester,
    ) async {
      final be = _backend(
        createPayout: (o) => jsonBody(409, {
          'error': {'code': 'INSUFFICIENT_AVAILABLE_BALANCE', 'message': 'no'},
        }),
      );
      await _pump(tester, initial: '/seller/payouts', backend: be);
      await tester.tap(find.byType(FloatingActionButton));
      await _settle(tester);
      await tester.enterText(_field('Сумма, ₸'), '100');
      await tester.tap(find.widgetWithText(FilledButton, 'Запросить'));
      await _settle(tester);
      expect(
        find.text('Недостаточно доступных средств для вывода'),
        findsOneWidget,
      );
      // CTA becomes retry, sheet stays open
      expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);
    });
  });
}
