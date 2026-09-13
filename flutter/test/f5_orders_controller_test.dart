import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/features/orders/application/orders_controller.dart';

import 'support/f4_harness.dart';
import 'support/f5_fixtures.dart';
import 'support/fake_dio.dart';

Future<F4Container> _loggedIn(MeBackend be) async {
  final h = await F4Container.create(backend: be);
  h.container.listen(ordersControllerProvider, (_, _) {});
  await h.settleAuth();
  await h.login();
  return h;
}

void main() {
  group('OrdersController', () {
    test('loads history after login, newest first', () async {
      final be = MeBackend()
        ..on(
          'GET /me/orders',
          (o) => okRaw([
            orderListItemJson(id: 3, number: 'MK-2026-000003'),
            orderListItemJson(id: 1, number: 'MK-2026-000001'),
          ]),
        );
      final h = await _loggedIn(be);
      await pumpUntil(
        () =>
            h.container.read(ordersControllerProvider).status ==
            OrdersStatus.loaded,
      );
      expect(
        h.container.read(ordersControllerProvider).items.map((o) => o.id),
        [3, 1],
      );
    });

    test('empty history → isEmpty', () async {
      final be = MeBackend()..on('GET /me/orders', (o) => okRaw(const []));
      final h = await _loggedIn(be);
      await pumpUntil(
        () =>
            h.container.read(ordersControllerProvider).status ==
            OrdersStatus.loaded,
      );
      expect(h.container.read(ordersControllerProvider).isEmpty, isTrue);
    });

    test('error then retry recovers', () async {
      var fail = true;
      final be = MeBackend()
        ..on(
          'GET /me/orders',
          (o) => fail
              ? jsonBody(500, {
                  'error': {'code': 'INTERNAL_ERROR', 'message': 'x'},
                })
              : okRaw([orderListItemJson()]),
        );
      final h = await _loggedIn(be);
      await pumpUntil(
        () =>
            h.container.read(ordersControllerProvider).status ==
            OrdersStatus.error,
      );
      fail = false;
      await h.container.read(ordersControllerProvider.notifier).refresh();
      expect(
        h.container.read(ordersControllerProvider).status,
        OrdersStatus.loaded,
      );
    });

    test('logout clears the list in memory', () async {
      final be = MeBackend()
        ..on('GET /me/orders', (o) => okRaw([orderListItemJson()]));
      final h = await _loggedIn(be);
      await pumpUntil(
        () => h.container.read(ordersControllerProvider).items.isNotEmpty,
      );
      await h.logout();
      await pumpUntil(
        () =>
            h.container.read(ordersControllerProvider).status ==
            OrdersStatus.loggedOut,
      );
      expect(h.container.read(ordersControllerProvider).items, isEmpty);
    });
  });

  group('orderDetailProvider', () {
    test('resolves one order', () async {
      final be = MeBackend()
        ..on('GET /me/orders/197', (o) => ok(orderDetailJson(id: 197)));
      final h = await _loggedIn(be);
      final order = await h.container.read(orderDetailProvider(197).future);
      expect(order.id, 197);
      expect(order.items, isNotEmpty);
    });

    test('404 surfaces as an error', () async {
      final be = MeBackend()
        ..on('GET /me/orders/999', (o) => notFoundBody('ORDER_NOT_FOUND'));
      final h = await _loggedIn(be);
      await expectLater(
        h.container.read(orderDetailProvider(999).future),
        throwsA(anything),
      );
    });
  });
}
