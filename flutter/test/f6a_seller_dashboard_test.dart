import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/seller/dashboard/application/seller_dashboard_controller.dart';
import 'package:nova_marketplace/features/seller/dashboard/data/seller_dashboard_repository.dart';

import 'support/f6a_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/f4_harness.dart';
import 'support/test_harness.dart';

ApiClient _client(FakeAdapter a) => ApiClient(
  tokenStore: TokenStore(FakeSecureStore()),
  tokenRefresher: const NoopTokenRefresher(),
  dio: Dio()..httpClientAdapter = a,
);

/// A logged-in **seller** with a MeBackend serving `/seller/dashboard`
/// (+ optionally `/sellers/1`).
Future<F4Container> _seller(MeBackend be, {int? sellerId = 1}) async {
  final h = await F4Container.create(
    backend: be,
    user: fakeUser(role: 'seller', sellerId: sellerId),
  );
  h.container.listen(sellerDashboardControllerProvider, (_, _) {});
  await h.settleAuth();
  await h.login();
  return h;
}

void main() {
  group('SellerDashboardRepository', () {
    test('parses the exact backend field set', () async {
      final adapter = FakeAdapter(
        (o, i) => ok(
          sellerDashboardJson(
            salesToday: '1237280.00',
            pendingBalance: '2787552.00',
            availableBalance: '2626800.00',
            activeOffers: 12,
            lowStockOffers: 2,
          ),
        ),
      );
      final m = await SellerDashboardRepository(
        _client(adapter),
      ).getDashboard();
      expect(m.salesToday, '1237280.00'); // exact string, not parsed
      expect(m.ordersToday, 6);
      expect(m.ordersTotal, 10);
      expect(m.pendingBalance, '2787552.00');
      expect(m.availableBalance, '2626800.00');
      expect(m.activeOffers, 12);
      expect(m.lowStockOffers, 2);
      expect(m.lowStockThreshold, 5);
      expect(m.rating, 4.9);
      expect(m.reviewCount, 1243);
      expect(m.hasLowStock, isTrue);
      expect(adapter.received.single.path, endsWith('/seller/dashboard'));
    });

    test('403 → ApiException(forbidden)', () async {
      final adapter = FakeAdapter(
        (o, i) => jsonBody(403, {
          'error': {'code': 'FORBIDDEN', 'message': 'no'},
        }),
      );
      await expectLater(
        SellerDashboardRepository(_client(adapter)).getDashboard(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.forbidden,
          ),
        ),
      );
    });
  });

  group('SellerDashboardController', () {
    test('loading → data, with identity from /sellers/:id', () async {
      final be = MeBackend()
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson(name: 'TechStore')));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerDashboardControllerProvider).status ==
            SellerDashboardStatus.data,
      );
      final v = h.container.read(sellerDashboardControllerProvider).view!;
      expect(v.metrics.ordersToday, 6);
      expect(v.sellerName, 'TechStore');
      expect(v.isVerified, isTrue);
      expect(v.identityLoaded, isTrue);
    });

    test('dashboard still renders when the identity call fails', () async {
      final be = MeBackend()
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on(
          'GET /sellers/1',
          (o) => jsonBody(500, {
            'error': {'code': 'X', 'message': 'down'},
          }),
        );
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerDashboardControllerProvider).status ==
            SellerDashboardStatus.data,
      );
      final v = h.container.read(sellerDashboardControllerProvider).view!;
      expect(v.metrics.activeOffers, 12);
      expect(v.sellerName, '');
      expect(v.identityLoaded, isFalse);
    });

    test('dashboard 500 → error, then refresh recovers', () async {
      var fail = true;
      final be = MeBackend()
        ..on(
          'GET /seller/dashboard',
          (o) => fail
              ? jsonBody(503, {
                  'error': {'code': 'X', 'message': 'down'},
                })
              : ok(sellerDashboardJson()),
        )
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerDashboardControllerProvider).status ==
            SellerDashboardStatus.error,
      );
      fail = false;
      await h.container
          .read(sellerDashboardControllerProvider.notifier)
          .refresh();
      expect(
        h.container.read(sellerDashboardControllerProvider).status,
        SellerDashboardStatus.data,
      );
    });

    test('403 on the dashboard → unavailable state', () async {
      final be = MeBackend()
        ..on(
          'GET /seller/dashboard',
          (o) => jsonBody(403, {
            'error': {'code': 'FORBIDDEN', 'message': 'no active seller'},
          }),
        );
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerDashboardControllerProvider).status ==
            SellerDashboardStatus.unavailable,
      );
      expect(h.container.read(sellerDashboardControllerProvider).view, isNull);
    });

    test('no linked seller id → unavailable, no API call', () async {
      final be = MeBackend()
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()));
      final h = await _seller(be, sellerId: null);
      await pumpUntil(
        () =>
            h.container.read(sellerDashboardControllerProvider).status ==
            SellerDashboardStatus.unavailable,
      );
      expect(be.countOf('GET', '/seller/dashboard'), 0);
    });
  });
}
