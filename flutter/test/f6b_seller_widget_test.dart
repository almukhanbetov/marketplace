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
import 'package:nova_marketplace/features/seller/offers/data/seller_offer_models.dart';
import 'package:nova_marketplace/features/seller/offers/presentation/add_offer_screen.dart';
import 'package:nova_marketplace/features/seller/offers/presentation/edit_offer_screen.dart';
import 'package:nova_marketplace/features/seller/offers/presentation/seller_offers_screen.dart';
import 'package:nova_marketplace/features/seller/offers/presentation/widgets/seller_offer_card.dart';
import 'package:nova_marketplace/features/seller/inventory/presentation/seller_inventory_screen.dart';
import 'package:nova_marketplace/shared/widgets/nova_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/catalog_fixtures.dart';
import 'support/f4_harness.dart';
import 'support/f6a_fixtures.dart';
import 'support/f6b_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

Future<void> _settle(WidgetTester t, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

/// The editable [TextField] inside the [NovaTextField] labelled [label].
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

MeBackend _backend() => MeBackend()
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
  ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
  ..on('GET /sellers/1', (o) => ok(sellerProfileJson()))
  ..on(
    'GET /products',
    (o) => okList([
      productCardJson(id: 10, nameRu: 'MacBook Pro 14'),
      productCardJson(id: 11, nameRu: 'iPad Air'),
    ], total: 2),
  );

Future<void> _pump(
  WidgetTester tester, {
  required String initial,
  MeBackend? backend,
  Object? extra,
}) async {
  final startAt = extra == null ? initial : '/seller/offers';
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final client = ApiClient(
    tokenStore: TokenStore(FakeSecureStore()),
    tokenRefresher: const NoopTokenRefresher(),
    dio: Dio()..httpClientAdapter = FakeAdapter((backend ?? _backend()).handle),
  );
  final router = GoRouter(
    initialLocation: startAt,
    routes: [
      GoRoute(
        path: '/seller/offers',
        builder: (_, _) => const SellerOffersScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const AddOfferScreen()),
          GoRoute(
            path: ':offerId/edit',
            builder: (_, s) => EditOfferScreen(
              offer: s.extra is SellerOfferModel
                  ? s.extra! as SellerOfferModel
                  : null,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/seller/inventory',
        builder: (_, _) => const SellerInventoryScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/catalog',
        builder: (_, _) => const Scaffold(body: Text('CATALOG')),
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
  if (extra != null) {
    await _settle(tester);
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).go(initial, extra: extra);
  }
  await _settle(tester);
}

void main() {
  group('SellerOffersScreen', () {
    testWidgets('renders cards with product/SKU/price/status, no overflow', (
      tester,
    ) async {
      for (final w in [360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(w, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await _pump(tester, initial: '/seller/offers');
        expect(tester.takeException(), isNull, reason: 'overflow @$w');
        expect(find.byType(SellerOfferCard), findsNWidgets(2));
        expect(find.text('SKU: SKU-A'), findsOneWidget);
        expect(find.text('Активно'), findsWidgets);
        expect(find.text('Неактивно'), findsOneWidget);
        expect(
          find.byType(FloatingActionButton),
          findsOneWidget,
        ); // add-offer FAB
      }
    });

    testWidgets('empty → localized add CTA', (tester) async {
      final be = _backend()
        ..on('GET /seller/offers', (o) => okList(const [], total: 0));
      await _pump(tester, initial: '/seller/offers', backend: be);
      expect(find.text('У вас пока нет предложений'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Добавить предложение'),
        findsWidgets,
      );
    });

    testWidgets('error → retry', (tester) async {
      final be = _backend()
        ..on(
          'GET /seller/offers',
          (o) => jsonBody(503, {
            'error': {'code': 'X', 'message': 'down'},
          }),
        );
      await _pump(tester, initial: '/seller/offers', backend: be);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('deactivate action calls the API and updates the card', (
      tester,
    ) async {
      var offers = [sellerOfferJson(id: 1, isActive: true)];
      final be = _backend()
        ..on('GET /seller/offers', (o) => okList(offers, total: offers.length))
        ..on('PATCH /seller/offers/1/status', (o) {
          offers = [sellerOfferJson(id: 1, isActive: false)];
          return ok({'updated': true});
        });
      await _pump(tester, initial: '/seller/offers', backend: be);
      expect(find.text('Деактивировать'), findsOneWidget);
      await tester.tap(find.text('Деактивировать'));
      await _settle(tester);
      expect(be.countOf('PATCH', '/seller/offers/1/status'), 1);
      expect(find.text('Активировать'), findsOneWidget);
    });
  });

  group('AddOfferScreen', () {
    testWidgets('prompts to pick a product first', (tester) async {
      await _pump(tester, initial: '/seller/offers/new');
      expect(
        find.widgetWithText(FilledButton, 'Выбрать товар'),
        findsOneWidget,
      );
    });

    testWidgets('pick product → form → blank submit shows validation', (
      tester,
    ) async {
      await _pump(tester, initial: '/seller/offers/new');
      await tester.tap(find.widgetWithText(FilledButton, 'Выбрать товар'));
      await _settle(tester);
      await tester.tap(find.text('MacBook Pro 14').first);
      await _settle(tester);
      // form is now shown
      expect(find.text('MacBook Pro 14'), findsWidgets);
      await tester.enterText(_field('Цена, ₸'), 'abc');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Добавить предложение').last,
      );
      await tester.pump();
      expect(find.textContaining('Введите корректную сумму'), findsOneWidget);
    });
  });

  group('EditOfferScreen', () {
    testWidgets('null offer → editUnavailable', (tester) async {
      await _pump(tester, initial: '/seller/offers/9/edit');
      expect(find.text('Не удалось открыть предложение'), findsOneWidget);
    });

    testWidgets('prefills the mutable fields, no stock field', (tester) async {
      final offer = SellerOfferModel.fromJson(
        sellerOfferJson(id: 5, sku: 'EDIT-ME', price: '333000.00'),
      );
      await _pump(tester, initial: '/seller/offers/5/edit', extra: offer);
      expect(
        tester.widget<TextField>(_field('SKU (артикул)')).controller?.text,
        'EDIT-ME',
      );
      expect(
        tester.widget<TextField>(_field('Цена, ₸')).controller?.text,
        '333000.00',
      );
      expect(find.text('Остаток, шт.'), findsNothing); // edit has no stock
    });
  });

  group('SellerInventoryScreen', () {
    testWidgets('rows + low-stock banner, no overflow', (tester) async {
      for (final w in [360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(w, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await _pump(tester, initial: '/seller/inventory');
        expect(tester.takeException(), isNull, reason: 'overflow @$w');
        expect(find.text('SKU: SKU-001-1'), findsWidgets);
        expect(find.textContaining('Заканчивается позиций'), findsOneWidget);
      }
    });

    testWidgets('edit opens the sheet and PATCHes', (tester) async {
      var qty = 3;
      final be = _backend()
        ..on(
          'GET /seller/inventory',
          (o) => okRaw([
            sellerInventoryJson(
              offerId: 1,
              available: qty,
              isLowStock: qty <= 5,
            ),
          ]),
        )
        ..on('PATCH /seller/inventory/1', (o) {
          qty = (o.data as Map)['available_quantity'] as int;
          return ok({'updated': true});
        });
      await _pump(tester, initial: '/seller/inventory', backend: be);
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await _settle(tester);
      expect(find.text('Изменить остаток'), findsOneWidget);
      await tester.enterText(_field('Доступное количество'), '25');
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await _settle(tester);
      expect(be.countOf('PATCH', '/seller/inventory/1'), 1);
      expect(qty, 25);
    });
  });
}
