import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/seller/dashboard/application/seller_dashboard_controller.dart';
import 'package:nova_marketplace/features/seller/inventory/application/seller_inventory_controller.dart';
import 'package:nova_marketplace/features/seller/offers/application/seller_offers_controller.dart';
import 'package:nova_marketplace/features/seller/offers/data/seller_offer_models.dart';
import 'package:nova_marketplace/features/seller/offers/data/seller_offers_repository.dart';

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
    ..listen(sellerOffersControllerProvider, (_, _) {})
    ..listen(sellerDashboardControllerProvider, (_, _) {})
    ..listen(sellerInventoryControllerProvider, (_, _) {});
  await h.settleAuth();
  await h.login();
  return h;
}

void main() {
  group('SellerOffersRepository', () {
    test('list parses page + forwards search/status/low_stock', () async {
      late RequestOptions req;
      final adapter = FakeAdapter((o, i) {
        req = o;
        return okList([
          sellerOfferJson(id: 1),
          sellerOfferJson(id: 2, isActive: false),
        ], total: 12);
      });
      final page = await SellerOffersRepository(_client(adapter)).list(
        search: 'phone',
        filter: SellerOfferFilter.inactive,
        lowStockOnly: true,
      );
      expect(page.items.map((o) => o.id), [1, 2]);
      expect(page.items[1].isActive, isFalse);
      expect(page.meta.total, 12);
      final q = req.uri.queryParameters;
      expect(q['search'], 'phone');
      expect(q['status'], 'inactive');
      expect(q['low_stock'], 'true');
    });

    test('create posts the body and returns the new id', () async {
      late Map<String, dynamic> body;
      final adapter = FakeAdapter((o, i) {
        body = Map<String, dynamic>.from(o.data as Map);
        return jsonBody(201, {
          'data': {'id': 999},
        });
      });
      final id = await SellerOffersRepository(_client(adapter)).create(
        const NewOfferInput(
          productId: 7,
          sku: 'S-1',
          price: '100.00',
          oldPrice: '',
          deliveryDays: 2,
          stock: 5,
        ),
      );
      expect(id, 999);
      expect(body['product_id'], 7);
      expect(body['sku'], 'S-1');
      expect(body['stock'], 5);
      expect(body['old_price'], '');
    });

    test('update PUTs only the mutable fields to /offers/:id', () async {
      late RequestOptions req;
      final adapter = FakeAdapter((o, i) {
        req = o;
        return ok({'updated': true});
      });
      await SellerOffersRepository(_client(adapter)).update(
        42,
        const EditOfferInput(sku: 'X', price: '9.99', deliveryDays: 1),
      );
      expect(req.method, 'PUT');
      expect(req.path, endsWith('/seller/offers/42'));
      final body = Map<String, dynamic>.from(req.data as Map);
      expect(body.keys.toSet(), {'sku', 'price', 'old_price', 'delivery_days'});
      expect(body.containsKey('product_id'), isFalse);
      expect(body.containsKey('stock'), isFalse);
    });

    test('setActive PATCHes /offers/:id/status', () async {
      late RequestOptions req;
      final adapter = FakeAdapter((o, i) {
        req = o;
        return ok({'updated': true});
      });
      await SellerOffersRepository(
        _client(adapter),
      ).setActive(5, active: false);
      expect(req.method, 'PATCH');
      expect(req.path, endsWith('/seller/offers/5/status'));
      expect((req.data as Map)['is_active'], false);
    });

    test('SKU_ALREADY_EXISTS surfaces as ApiException(conflict)', () async {
      final adapter = FakeAdapter(
        (o, i) => jsonBody(409, {
          'error': {'code': 'SKU_ALREADY_EXISTS', 'message': 'dup'},
        }),
      );
      await expectLater(
        SellerOffersRepository(_client(adapter)).create(
          const NewOfferInput(
            productId: 1,
            sku: 'dup',
            price: '1.00',
            deliveryDays: 1,
            stock: 1,
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'SKU_ALREADY_EXISTS',
          ),
        ),
      );
    });
  });

  group('SellerOffersController', () {
    MeBackend baseBackend({List<Map<String, dynamic>>? offers}) {
      final list = offers ?? [sellerOfferJson(id: 1), sellerOfferJson(id: 2)];
      return MeBackend()
        ..on('GET /seller/offers', (o) => okList(list, total: list.length))
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()))
        ..on('GET /seller/inventory', (o) => okRaw(const []));
    }

    test('initial load fills items + total', () async {
      final h = await _seller(baseBackend());
      await pumpUntil(
        () =>
            h.container.read(sellerOffersControllerProvider).status ==
            SellerOffersStatus.loaded,
      );
      expect(
        h.container.read(sellerOffersControllerProvider).items,
        hasLength(2),
      );
      expect(h.container.read(sellerOffersControllerProvider).total, 2);
    });

    test('createOffer POSTs, refreshes list, invalidates siblings', () async {
      var offers = [sellerOfferJson(id: 1)];
      final be = MeBackend()
        ..on('GET /seller/offers', (o) => okList(offers, total: offers.length))
        ..on('POST /seller/offers', (o) {
          offers = [sellerOfferJson(id: 1), sellerOfferJson(id: 2, sku: 'NEW')];
          return jsonBody(201, {
            'data': {'id': 2},
          });
        })
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()))
        ..on('GET /seller/inventory', (o) => okRaw(const []));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerOffersControllerProvider).status ==
            SellerOffersStatus.loaded,
      );

      await h.container
          .read(sellerOffersControllerProvider.notifier)
          .createOffer(
            const NewOfferInput(
              productId: 5,
              sku: 'NEW',
              price: '100.00',
              deliveryDays: 1,
              stock: 3,
            ),
          );
      expect(
        h.container.read(sellerOffersControllerProvider).items,
        hasLength(2),
      );
      expect(be.countOf('POST', '/seller/offers'), 1);
    });

    test(
      'setActive toggles, marks the offer mutating, then refreshes',
      () async {
        var offers = [sellerOfferJson(id: 1, isActive: true)];
        final be = MeBackend()
          ..on(
            'GET /seller/offers',
            (o) => okList(offers, total: offers.length),
          )
          ..on('PATCH /seller/offers/1/status', (o) {
            offers = [sellerOfferJson(id: 1, isActive: false)];
            return ok({'updated': true});
          })
          ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
          ..on('GET /sellers/1', (o) => ok(sellerProfileJson()))
          ..on('GET /seller/inventory', (o) => okRaw(const []));
        final h = await _seller(be);
        await pumpUntil(
          () =>
              h.container.read(sellerOffersControllerProvider).status ==
              SellerOffersStatus.loaded,
        );

        await h.container
            .read(sellerOffersControllerProvider.notifier)
            .setActive(1, active: false);
        expect(
          h.container
              .read(sellerOffersControllerProvider)
              .items
              .single
              .isActive,
          isFalse,
        );
        expect(
          h.container.read(sellerOffersControllerProvider).mutating,
          isEmpty,
        );
      },
    );

    test('applyQuery(lowStockOnly) reloads with the filter', () async {
      var lastLowStock = '';
      final be = MeBackend()
        ..on('GET /seller/offers', (o) {
          lastLowStock = o.uri.queryParameters['low_stock'] ?? '';
          return okList([sellerOfferJson(id: 1)], total: 1);
        })
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()))
        ..on('GET /seller/inventory', (o) => okRaw(const []));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerOffersControllerProvider).status ==
            SellerOffersStatus.loaded,
      );
      h.container
          .read(sellerOffersControllerProvider.notifier)
          .applyQuery(lowStockOnly: true);
      await pumpUntil(() => lastLowStock == 'true');
      expect(
        h.container.read(sellerOffersControllerProvider).lowStockOnly,
        isTrue,
      );
    });

    test('list failure → error state, retry recovers', () async {
      var fail = true;
      final be = MeBackend()
        ..on(
          'GET /seller/offers',
          (o) => fail
              ? jsonBody(503, {
                  'error': {'code': 'X', 'message': 'down'},
                })
              : okList([sellerOfferJson(id: 1)], total: 1),
        )
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()))
        ..on('GET /seller/inventory', (o) => okRaw(const []));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerOffersControllerProvider).status ==
            SellerOffersStatus.error,
      );
      fail = false;
      await h.container.read(sellerOffersControllerProvider.notifier).refresh();
      expect(
        h.container.read(sellerOffersControllerProvider).status,
        SellerOffersStatus.loaded,
      );
    });
  });
}
