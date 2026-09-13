import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/orders/data/order_models.dart';
import 'package:nova_marketplace/features/seller/dashboard/application/seller_dashboard_controller.dart';
import 'package:nova_marketplace/features/seller/orders/application/seller_orders_controller.dart';
import 'package:nova_marketplace/features/seller/orders/data/seller_order_models.dart';
import 'package:nova_marketplace/features/seller/orders/data/seller_orders_repository.dart';

import 'support/f4_harness.dart';
import 'support/f6a_fixtures.dart';
import 'support/f6c_fixtures.dart';
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
    ..listen(sellerOrdersControllerProvider, (_, _) {})
    ..listen(sellerDashboardControllerProvider, (_, _) {});
  await h.settleAuth();
  await h.login();
  return h;
}

void main() {
  group('SellerOrdersRepository', () {
    test('list parses seller-scoped rows + meta', () async {
      late RequestOptions req;
      final adapter = FakeAdapter((o, i) {
        req = o;
        return okList([
          sellerOrderListJson(orderId: 145, sellerItemCount: 1),
          sellerOrderListJson(
            orderId: 144,
            number: 'MK-2026-000144',
            sellerItemCount: 3,
            gross: '900000.00',
            net: '810000.00',
          ),
        ], total: 20);
      });
      final page = await SellerOrdersRepository(_client(adapter)).list();
      expect(page.items.map((o) => o.orderId), [145, 144]);
      expect(page.items.first.status, OrderStatus.paid);
      expect(page.items.first.sellerGrossAmount, '558000.00');
      expect(page.items[1].sellerItemCount, 3);
      expect(page.meta.total, 20);
      expect(req.path, endsWith('/seller/orders'));
    });

    test('detail parses only this seller\'s lines + amounts', () async {
      final adapter = FakeAdapter(
        (o, i) => ok(
          sellerOrderDetailJson(
            items: [
              sellerOrderItemJson(name: 'iPhone 17 Pro 256GB', sku: 'A'),
              sellerOrderItemJson(
                name: 'AirPods Pro',
                sku: 'B',
                quantity: 2,
                unitPrice: '90000.00',
                totalPrice: '180000.00',
              ),
            ],
            gross: '800000.00',
            commission: '80000.00',
            net: '720000.00',
          ),
        ),
      );
      final d = await SellerOrdersRepository(_client(adapter)).getOrder(145);
      expect(d.items, hasLength(2));
      expect(d.itemCount, 3);
      expect(d.delivery.city, 'Алматы');
      expect(d.sellerNetAmount, '720000.00');
      // historical snapshot values, verbatim
      expect(d.items.first.unitPrice, '620000.00');
    });

    test('404 → ApiException(notFound / ORDER_NOT_FOUND)', () async {
      final adapter = FakeAdapter((o, i) => notFoundBody('ORDER_NOT_FOUND'));
      await expectLater(
        SellerOrdersRepository(_client(adapter)).getOrder(999),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.notFound)
              .having((e) => e.code, 'code', 'ORDER_NOT_FOUND'),
        ),
      );
    });
  });

  group('SellerOrdersController', () {
    MeBackend backend({List<Map<String, dynamic>>? orders, int total = 2}) {
      final list =
          orders ??
          [
            sellerOrderListJson(orderId: 145),
            sellerOrderListJson(orderId: 144, number: 'MK-2026-000144'),
          ];
      return MeBackend()
        ..on('GET /seller/orders', (o) => okList(list, total: total))
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
    }

    test('initial load fills items + total', () async {
      final h = await _seller(backend());
      await pumpUntil(
        () =>
            h.container.read(sellerOrdersControllerProvider).status ==
            SellerOrdersStatus.loaded,
      );
      expect(
        h.container.read(sellerOrdersControllerProvider).items,
        hasLength(2),
      );
      expect(h.container.read(sellerOrdersControllerProvider).total, 2);
    });

    test('empty history → isEmpty', () async {
      final h = await _seller(backend(orders: const [], total: 0));
      await pumpUntil(
        () =>
            h.container.read(sellerOrdersControllerProvider).status ==
            SellerOrdersStatus.loaded,
      );
      expect(h.container.read(sellerOrdersControllerProvider).isEmpty, isTrue);
    });

    test('error then refresh recovers', () async {
      var fail = true;
      final be = MeBackend()
        ..on(
          'GET /seller/orders',
          (o) => fail
              ? jsonBody(503, {
                  'error': {'code': 'X', 'message': 'down'},
                })
              : okList([sellerOrderListJson()], total: 1),
        )
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerOrdersControllerProvider).status ==
            SellerOrdersStatus.error,
      );
      fail = false;
      await h.container.read(sellerOrdersControllerProvider.notifier).refresh();
      expect(
        h.container.read(sellerOrdersControllerProvider).status,
        SellerOrdersStatus.loaded,
      );
    });

    test('loadMore appends the next page without duplicates', () async {
      final be = MeBackend()
        ..on('GET /seller/orders', (o) {
          final offset = int.parse(o.uri.queryParameters['offset'] ?? '0');
          return okList(
            [
              for (var k = offset; k < offset + 20 && k < 45; k++)
                sellerOrderListJson(orderId: 1000 - k, number: 'MK-$k'),
            ],
            limit: 20,
            offset: offset,
            total: 45,
          );
        })
        ..on('GET /seller/dashboard', (o) => ok(sellerDashboardJson()))
        ..on('GET /sellers/1', (o) => ok(sellerProfileJson()));
      final h = await _seller(be);
      await pumpUntil(
        () =>
            h.container.read(sellerOrdersControllerProvider).items.length == 20,
      );
      await h.container
          .read(sellerOrdersControllerProvider.notifier)
          .loadMore();
      final st = h.container.read(sellerOrdersControllerProvider);
      expect(st.items, hasLength(40));
      expect(st.items.map((o) => o.orderId).toSet(), hasLength(40));
    });
  });

  group('privacy (model level)', () {
    test('two sellers on the same order get disjoint item sets', () {
      // Seller A's response for order 145.
      final a = SellerOrderDetail.fromJson(
        sellerOrderDetailJson(
          items: [sellerOrderItemJson(name: 'iPhone 17 Pro', sku: 'A-1')],
          net: '558000.00',
        ),
      );
      // Seller B's response for the SAME order 145.
      final b = SellerOrderDetail.fromJson(
        sellerOrderDetailJson(
          items: [
            sellerOrderItemJson(name: 'Galaxy S25 Ultra', sku: 'B-1'),
            sellerOrderItemJson(name: 'ROG Zephyrus', sku: 'B-2'),
          ],
          net: '1800000.00',
        ),
      );
      expect(a.orderId, b.orderId); // same customer order
      final aNames = a.items.map((i) => i.productName).toSet();
      final bNames = b.items.map((i) => i.productName).toSet();
      expect(aNames.intersection(bNames), isEmpty);
      expect(a.sellerNetAmount, isNot(b.sellerNetAmount));
      // A never carries B's SKUs or amounts, and vice versa.
      expect(a.items.any((i) => i.sku.startsWith('B')), isFalse);
      expect(b.items.any((i) => i.sku.startsWith('A')), isFalse);
    });
  });
}
