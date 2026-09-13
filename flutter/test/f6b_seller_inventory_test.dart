import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/seller/dashboard/application/seller_dashboard_controller.dart';
import 'package:nova_marketplace/features/seller/inventory/application/seller_inventory_controller.dart';
import 'package:nova_marketplace/features/seller/inventory/data/seller_inventory_repository.dart';

import 'support/f4_harness.dart';
import 'support/f6a_fixtures.dart';
import 'support/f6b_fixtures.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

ApiClient _client(FakeAdapter a) => ApiClient(
  tokenStore: TokenStore(FakeSecureStore()),
  tokenRefresher: const NoopTokenRefresher(),
  dio: Dio()..httpClientAdapter = a,
);

Future<F4Container> _seller(MeBackend be) async {
  final h = await F4Container.create(
    backend: be,
    user: fakeUser(role: 'seller', sellerId: 1),
  );
  h.container
    ..listen(sellerInventoryControllerProvider, (_, _) {})
    ..listen(sellerDashboardControllerProvider, (_, _) {});
  await h.settleAuth();
  await h.login();
  return h;
}

void main() {
  group('SellerInventoryRepository', () {
    test('list parses the plain array', () async {
      final adapter = FakeAdapter(
        (o, i) => okRaw([
          sellerInventoryJson(offerId: 1, isLowStock: true),
          sellerInventoryJson(offerId: 2, available: 50, isLowStock: false),
        ]),
      );
      final items = await SellerInventoryRepository(_client(adapter)).list();
      expect(items.map((x) => x.offerId), [1, 2]);
      expect(items.first.isLowStock, isTrue);
      expect(items[1].availableQuantity, 50);
    });

    test('updateQuantity PATCHes /inventory/:offerId', () async {
      late RequestOptions req;
      final adapter = FakeAdapter((o, i) {
        req = o;
        return ok({'updated': true});
      });
      await SellerInventoryRepository(_client(adapter)).updateQuantity(9, 12);
      expect(req.method, 'PATCH');
      expect(req.path, endsWith('/seller/inventory/9'));
      expect((req.data as Map)['available_quantity'], 12);
    });
  });

  group('SellerInventoryController', () {
    MeBackend backend({List<Map<String, dynamic>>? items}) {
      final list =
          items ??
          [
            sellerInventoryJson(offerId: 1, available: 3, isLowStock: true),
            sellerInventoryJson(offerId: 2, available: 40, isLowStock: false),
          ];
      return MeBackend()
        ..on('GET /seller/inventory', (o) => okRaw(list))
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
    }

    test('loads the list; lowStockCount reflects the backend flag', () async {
      final h = await _seller(backend());
      await pumpUntil(
        () =>
            h.container.read(sellerInventoryControllerProvider).status ==
            SellerInventoryStatus.loaded,
      );
      final st = h.container.read(sellerInventoryControllerProvider);
      expect(st.items, hasLength(2));
      expect(st.lowStockCount, 1);
    });

    test(
      'updateQuantity PATCHes, refreshes, invalidates the dashboard',
      () async {
        var qty = 3;
        final be = MeBackend()
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
          })
          ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
          ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
        final h = await _seller(be);
        await pumpUntil(
          () =>
              h.container.read(sellerInventoryControllerProvider).status ==
              SellerInventoryStatus.loaded,
        );

        await h.container
            .read(sellerInventoryControllerProvider.notifier)
            .updateQuantity(1, 30);
        final st = h.container.read(sellerInventoryControllerProvider);
        expect(st.items.single.availableQuantity, 30);
        expect(st.items.single.isLowStock, isFalse); // backend recomputed
        expect(st.mutating, isEmpty);
        expect(be.countOf('PATCH', '/seller/inventory/1'), 1);
      },
    );

    test('a busy row is not PATCHed twice', () async {
      var patches = 0;
      final be = MeBackend()
        ..on(
          'GET /seller/inventory',
          (o) => okRaw([sellerInventoryJson(offerId: 1)]),
        )
        ..on('PATCH /seller/inventory/1', (o) {
          patches++;
          return ok({'updated': true});
        })
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerInventoryControllerProvider).status ==
            SellerInventoryStatus.loaded,
      );
      final n = h.container.read(sellerInventoryControllerProvider.notifier);
      await Future.wait([n.updateQuantity(1, 5), n.updateQuantity(1, 9)]);
      expect(patches, 1);
    });

    test('list failure → error state', () async {
      final be = MeBackend()
        ..on(
          'GET /seller/inventory',
          (o) => jsonBody(500, {
            'error': {'code': 'X', 'message': 'down'},
          }),
        )
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerInventoryControllerProvider).status ==
            SellerInventoryStatus.error,
      );
      expect(
        h.container.read(sellerInventoryControllerProvider).error,
        isA<ApiException>(),
      );
    });
  });
}
