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
import 'package:nova_marketplace/features/addresses/presentation/address_form_screen.dart';
import 'package:nova_marketplace/features/addresses/presentation/addresses_screen.dart';
import 'package:nova_marketplace/features/cart/data/cart_models.dart';
import 'package:nova_marketplace/features/cart/presentation/cart_screen.dart';
import 'package:nova_marketplace/features/cart/presentation/widgets/cart_item_tile.dart';
import 'package:nova_marketplace/features/cart/presentation/widgets/cart_summary_bar.dart';
import 'package:nova_marketplace/features/favorites/presentation/favorites_screen.dart';
import 'package:nova_marketplace/shared/widgets/product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/f4_fixtures.dart';
import 'support/f4_harness.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

Future<void> _pump(WidgetTester t) async {
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

BuildContext _ctx(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

FakeAuthRepository _customerRepo() => FakeAuthRepository(
  onRefresh: () async => fakeTokens(),
  onMe: () async => fakeUser(role: 'customer'),
  onLogin: (_) async => AuthSession(
    tokens: fakeTokens(),
    user: fakeUser(role: 'customer'),
  ),
);

/// Pumps the full app with a fake `/me/*` backend and (optionally) a
/// restored customer session.
Future<void> _pumpApp(
  WidgetTester tester, {
  required MeBackend backend,
  bool authed = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final adapter = FakeAdapter(backend.handle);
  final client = ApiClient(
    tokenStore: TokenStore(FakeSecureStore()),
    tokenRefresher: const NoopTokenRefresher(),
    dio: Dio()..httpClientAdapter = adapter,
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        secureStoreProvider.overrideWithValue(
          FakeSecureStore(refreshToken: authed ? 'stored' : null),
        ),
        authRepositoryProvider.overrideWithValue(
          authed ? _customerRepo() : FakeAuthRepository(),
        ),
        apiClientProvider.overrideWithValue(client),
      ],
      child: const NovaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a single F4 screen at [initialPath] inside a minimal router (no
/// HomeScreen), with a restored customer session and a fake `/me/*`
/// backend. Keeps overflow assertions scoped to the F4 screen itself.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required String initialPath,
  required MeBackend backend,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final adapter = FakeAdapter(backend.handle);
  final client = ApiClient(
    tokenStore: TokenStore(FakeSecureStore()),
    tokenRefresher: const NoopTokenRefresher(),
    dio: Dio()..httpClientAdapter = adapter,
  );
  final router = GoRouter(
    initialLocation: initialPath,
    routes: [
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(
        path: '/profile/addresses',
        builder: (_, _) => const AddressesScreen(),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (_, _) => const Scaffold(body: Text('product')),
      ),
      GoRoute(
        path: '/seller/:id',
        builder: (_, _) => const Scaffold(body: Text('seller')),
      ),
      GoRoute(
        path: '/checkout',
        builder: (_, _) => const Scaffold(body: Text('checkout')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('login')),
      ),
      GoRoute(path: '/catalog', builder: (_, _) => const Scaffold()),
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
        authRepositoryProvider.overrideWithValue(_customerRepo()),
        apiClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  // Not pumpAndSettle: network-image shimmer animates forever.
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<Widget> _wrap(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      secureStoreProvider.overrideWithValue(FakeSecureStore()),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('route guards (§80 / F5 §74)', () {
    for (final path in [
      '/favorites',
      '/cart',
      '/profile/addresses',
      '/checkout',
      '/profile/orders',
    ]) {
      testWidgets('anonymous → $path redirects to login', (tester) async {
        await _pumpApp(tester, backend: MeBackend());
        _ctx(tester).go(path);
        await tester.pumpAndSettle();
        expect(find.text('Вход'), findsWidgets);
      });
    }
  });

  testWidgets('customer /cart: multi-seller groups render, no overflow', (
    tester,
  ) async {
    for (final width in [360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final be = MeBackend()
        ..on(
          'GET /me/cart',
          (o) => ok(
            cartJson(
              items: [
                cartItemJson(
                  id: 1,
                  sellerOfferId: 100,
                  sellerId: 1,
                  sellerName: 'TechStore',
                ),
                cartItemJson(
                  id: 2,
                  sellerOfferId: 200,
                  sellerId: 4,
                  sellerName: 'GadgetPro',
                ),
              ],
              itemCount: 2,
              subtotal: '1240000.00',
            ),
          ),
        );
      await _pumpScreen(tester, initialPath: '/cart', backend: be);
      await _pump(tester);

      expect(tester.takeException(), isNull, reason: 'overflow at ${width}px');
      expect(find.text('TechStore'), findsOneWidget);
      expect(find.text('GadgetPro'), findsOneWidget);
      expect(find.byType(CartSummaryBar), findsOneWidget);
    }
  });

  testWidgets('customer /cart: empty state', (tester) async {
    final be = MeBackend()..on('GET /me/cart', (o) => ok(cartJson()));
    await _pumpScreen(tester, initialPath: '/cart', backend: be);
    await _pump(tester);
    expect(find.text('Корзина пуста'), findsOneWidget);
  });

  testWidgets('customer /favorites: grid renders backend items', (
    tester,
  ) async {
    final be = MeBackend()
      ..on(
        'GET /me/favorites',
        (o) => okRaw([favoriteCardJson(id: 1), favoriteCardJson(id: 2)]),
      );
    await _pumpScreen(tester, initialPath: '/favorites', backend: be);
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('iPhone'), findsWidgets);
  });

  testWidgets('customer /profile/addresses: list renders', (tester) async {
    final be = MeBackend()
      ..on('GET /me/addresses', (o) => okRaw([addressJson(id: 1)]));
    await _pumpScreen(tester, initialPath: '/profile/addresses', backend: be);
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Алматы'), findsWidgets);
  });

  group('standalone widgets', () {
    testWidgets('CartSummaryBar formats the backend subtotal', (tester) async {
      await tester.pumpWidget(
        await _wrap(
          const CartSummaryBar(
            cart: CartModel(items: [], itemCount: 0, subtotal: '1700000.00'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('CartItemTile: plus disabled at stock limit, no overflow', (
      tester,
    ) async {
      for (final width in [360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          await _wrap(
            CartItemTile(
              item: CartItemModel.fromJson(
                cartItemJson(quantity: 5, availableQuantity: 5),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'overflow at $width');
        expect(find.bySemanticsLabel('plus'), findsOneWidget);
      }
    });

    testWidgets('AddressFormScreen: blank submit shows validation errors', (
      tester,
    ) async {
      await tester.pumpWidget(await _wrap(const AddressFormScreen()));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Укажите город'), findsOneWidget);
    });
  });

  testWidgets('ProductCard heart: anonymous tap routes to login (§9)', (
    tester,
  ) async {
    final be = MeBackend();
    final adapter = FakeAdapter(be.handle);
    final client = ApiClient(
      tokenStore: TokenStore(FakeSecureStore()),
      tokenRefresher: const NoopTokenRefresher(),
      dio: Dio()..httpClientAdapter = adapter,
    );
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/catalog',
      routes: [
        GoRoute(
          path: '/catalog',
          builder: (_, _) => Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 320,
                child: ProductCard(product: favoriteModel(id: 1)),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN PAGE')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          apiClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });
}
