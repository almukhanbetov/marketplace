import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/orders/data/order_models.dart';
import 'package:nova_marketplace/features/orders/data/order_repository.dart';
import 'package:nova_marketplace/features/orders/data/payment_method.dart';

import 'support/f5_fixtures.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

ApiClient _client(FakeAdapter a) => ApiClient(
  tokenStore: TokenStore(FakeSecureStore()),
  tokenRefresher: const NoopTokenRefresher(),
  dio: Dio()..httpClientAdapter = a,
);

void main() {
  group('createOrder', () {
    test(
      'sends only address_id + payment_provider, key in header (§51/§52)',
      () async {
        late RequestOptions sent;
        final adapter = FakeAdapter((o, i) {
          sent = o;
          return jsonBody(201, {'data': orderDetailJson()});
        });
        final result = await OrderRepository(_client(adapter)).createOrder(
          addressId: 77,
          payment: PaymentMethod.kaspi,
          idempotencyKey: 'attempt-key-1',
        );

        final body = Map<String, dynamic>.from(sent.data as Map);
        expect(body.keys.toSet(), {'address_id', 'payment_provider'});
        expect(body['address_id'], 77);
        expect(body['payment_provider'], 'kaspi_mock');
        // never a price / total / seller / item list
        for (final forbidden in [
          'price',
          'total',
          'subtotal',
          'seller_id',
          'items',
          'commission',
        ]) {
          expect(body.containsKey(forbidden), isFalse, reason: forbidden);
        }
        expect(sent.headers['Idempotency-Key'], 'attempt-key-1');
        expect(sent.method, 'POST');
        expect(sent.path, endsWith('/me/orders'));
        expect(result.order.orderNumber, 'MK-2026-000197');
        expect(result.order.status, OrderStatus.paid);
      },
    );

    test('maps CART_EMPTY / INSUFFICIENT_STOCK / ADDRESS_NOT_FOUND', () async {
      for (final (status, code) in [
        (400, 'CART_EMPTY'),
        (409, 'INSUFFICIENT_STOCK'),
        (404, 'ADDRESS_NOT_FOUND'),
      ]) {
        final adapter = FakeAdapter(
          (o, i) => jsonBody(status, {
            'error': {'code': code, 'message': 'x'},
          }),
        );
        await expectLater(
          OrderRepository(_client(adapter)).createOrder(
            addressId: 1,
            payment: PaymentMethod.card,
            idempotencyKey: 'k',
          ),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
        );
      }
    });
  });

  group('getOrders', () {
    test('parses the list newest-first with previews', () async {
      final adapter = FakeAdapter(
        (o, i) => okRaw([
          orderListItemJson(id: 2, number: 'MK-2026-000002', itemCount: 3),
          orderListItemJson(id: 1, number: 'MK-2026-000001', itemCount: 1),
        ]),
      );
      final list = await OrderRepository(_client(adapter)).getOrders();
      expect(list.map((o) => o.id), [2, 1]);
      expect(list.first.itemCount, 3);
      expect(list.first.itemsPreview, isNotEmpty);
      expect(list.first.total, isNotEmpty);
    });
  });

  group('getOrder', () {
    test(
      'parses detail incl. multi-seller grouping + address snapshot',
      () async {
        final adapter = FakeAdapter(
          (o, i) => ok(orderDetailJson(multiSeller: true)),
        );
        final order = await OrderRepository(_client(adapter)).getOrder(197);
        expect(order.items.length, 3);
        expect(order.groupedBySeller.length, greaterThanOrEqualTo(2));
        expect(order.delivery.city, 'Алматы');
        expect(order.payment?.provider, PaymentMethod.kaspi);
        expect(order.payment?.status, PaymentStatus.paid);
        // snapshot prices are used verbatim
        expect(order.items.first.unitPrice, '620000.00');
      },
    );

    test('404 → ApiException(notFound / ORDER_NOT_FOUND)', () async {
      final adapter = FakeAdapter((o, i) => notFoundBody('ORDER_NOT_FOUND'));
      await expectLater(
        OrderRepository(_client(adapter)).getOrder(999),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.notFound)
              .having((e) => e.code, 'code', 'ORDER_NOT_FOUND'),
        ),
      );
    });
  });
}
