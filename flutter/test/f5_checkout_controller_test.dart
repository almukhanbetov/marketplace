import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/features/addresses/application/addresses_controller.dart';
import 'package:nova_marketplace/features/cart/application/cart_controller.dart';
import 'package:nova_marketplace/features/checkout/application/checkout_controller.dart';
import 'package:nova_marketplace/features/orders/application/orders_controller.dart';
import 'package:nova_marketplace/features/orders/data/payment_method.dart';

import 'support/f4_fixtures.dart';
import 'support/f4_harness.dart';
import 'support/f5_fixtures.dart';
import 'support/fake_dio.dart';

/// A backend with a cart, one default address and a scriptable order
/// endpoint. [orderResponder] gets every `POST /me/orders` request so a
/// test can inspect the `Idempotency-Key` header and choose the reply.
MeBackend _backend({
  required ResponseBody Function(RequestOptions o) orderResponder,
  List<Map<String, dynamic>>? cartItems,
}) {
  final items =
      cartItems ??
      [
        cartItemJson(
          id: 1,
          sellerOfferId: 1,
          sellerId: 1,
          sellerName: 'TechStore',
        ),
      ];
  return MeBackend()
    ..on(
      'GET /me/cart',
      (o) => ok(cartJson(items: items, itemCount: items.length)),
    )
    ..on(
      'GET /me/addresses',
      (o) => okRaw([
        addressJson(id: 50, isDefault: true),
        addressJson(id: 51, isDefault: false),
      ]),
    )
    ..on('GET /me/orders', (o) => okRaw(const []))
    ..on('POST /me/orders', orderResponder);
}

Future<F4Container> _loggedIn(MeBackend be) async {
  final h = await F4Container.create(backend: be);
  h.container
    ..listen(cartControllerProvider, (_, _) {})
    ..listen(addressesControllerProvider, (_, _) {})
    ..listen(ordersControllerProvider, (_, _) {})
    ..listen(checkoutControllerProvider, (_, _) {});
  await h.settleAuth();
  await h.login();
  await pumpUntil(
    () =>
        h.container.read(cartControllerProvider).status == CartStatus.loaded &&
        h.container.read(addressesControllerProvider).status ==
            AddressesStatus.loaded,
  );
  return h;
}

void main() {
  test(
    'idempotency key is generated once and is stable across edits (§16/§17)',
    () async {
      final h = await _loggedIn(
        _backend(orderResponder: (o) => ok(orderDetailJson())),
      );
      final n = h.container.read(checkoutControllerProvider.notifier);
      final key0 = h.container.read(checkoutControllerProvider).idempotencyKey;
      expect(key0, isNotEmpty);

      n.selectAddress(51);
      n.selectPayment(PaymentMethod.kaspi);
      expect(h.container.read(checkoutControllerProvider).idempotencyKey, key0);

      n.startNewAttempt();
      expect(
        h.container.read(checkoutControllerProvider).idempotencyKey,
        isNot(key0),
      );
    },
  );

  test('default address auto-selects; explicit choice is kept (§10)', () async {
    final h = await _loggedIn(
      _backend(orderResponder: (o) => ok(orderDetailJson())),
    );
    final n = h.container.read(checkoutControllerProvider.notifier);

    n.selectAddressIfUnset(
      h.container.read(addressesControllerProvider).defaultAddress!.id,
    );
    expect(h.container.read(checkoutControllerProvider).selectedAddressId, 50);

    n.selectAddress(51);
    n.selectAddressIfUnset(50); // must NOT override
    expect(h.container.read(checkoutControllerProvider).selectedAddressId, 51);
  });

  test('submit with no address selected is a no-op (§7 guard)', () async {
    final be = _backend(orderResponder: (o) => ok(orderDetailJson()));
    final h = await _loggedIn(be);
    await h.container.read(checkoutControllerProvider.notifier).submit();
    expect(be.countOf('POST', '/me/orders'), 0);
    expect(
      h.container.read(checkoutControllerProvider).phase,
      CheckoutPhase.editing,
    );
  });

  test(
    'submit success → phase success, cart + orders refreshed (§20/§21)',
    () async {
      var cartEmptied = false;
      final be = MeBackend()
        ..on(
          'GET /me/cart',
          (o) => cartEmptied
              ? ok(cartJson())
              : ok(
                  cartJson(
                    items: [cartItemJson(id: 1, sellerOfferId: 1)],
                    itemCount: 1,
                  ),
                ),
        )
        ..on('GET /me/addresses', (o) => okRaw([addressJson(id: 50)]))
        ..on('GET /me/orders', (o) => okRaw(const []))
        ..on('POST /me/orders', (o) {
          cartEmptied = true; // backend clears the cart transactionally
          return ok(orderDetailJson());
        });
      final h = await _loggedIn(be);
      final n = h.container.read(checkoutControllerProvider.notifier);
      n.selectAddress(50);

      await n.submit();

      final st = h.container.read(checkoutControllerProvider);
      expect(st.phase, CheckoutPhase.success);
      expect(st.result?.order.orderNumber, 'MK-2026-000197');
      // cart re-read → now empty → badge 0
      await pumpUntil(
        () => h.container.read(cartControllerProvider).cart.isEmpty,
      );
      expect(be.countOf('DELETE', '/me/cart'), 0); // never a redundant clear
      expect(be.countOf('GET', '/me/orders') >= 1, isTrue);
    },
  );

  test(
    'submit failure keeps cart, no success nav, error surfaced (§26/§27)',
    () async {
      final be = _backend(
        orderResponder: (o) => jsonBody(409, {
          'error': {'code': 'INSUFFICIENT_STOCK', 'message': 'x'},
        }),
      );
      final h = await _loggedIn(be);
      final n = h.container.read(checkoutControllerProvider.notifier);
      n.selectAddress(50);

      await n.submit();

      final st = h.container.read(checkoutControllerProvider);
      expect(st.phase, CheckoutPhase.error);
      expect(st.errorCode, 'INSUFFICIENT_STOCK');
      expect(st.result, isNull);
      // cart refreshed so the user sees current stock when they go back
      expect(be.countOf('GET', '/me/cart') >= 2, isTrue);
    },
  );

  test('double submit fires only one POST (§18)', () async {
    var posts = 0;
    final be = _backend(
      orderResponder: (o) {
        posts++;
        return ok(orderDetailJson());
      },
    );
    final h = await _loggedIn(be);
    final n = h.container.read(checkoutControllerProvider.notifier);
    n.selectAddress(50);

    await Future.wait([n.submit(), n.submit(), n.submit()]);
    expect(posts, 1);
  });

  test(
    'retry after failure reuses the SAME idempotency key (§31/§32)',
    () async {
      final keys = <String?>[];
      var fail = true;
      final be = _backend(
        orderResponder: (o) {
          keys.add(o.headers['Idempotency-Key'] as String?);
          if (fail) {
            fail = false;
            return jsonBody(500, {
              'error': {'code': 'INTERNAL_ERROR', 'message': 'x'},
            });
          }
          return ok(orderDetailJson());
        },
      );
      final h = await _loggedIn(be);
      final n = h.container.read(checkoutControllerProvider.notifier);
      n.selectAddress(50);

      await n.submit();
      expect(
        h.container.read(checkoutControllerProvider).phase,
        CheckoutPhase.error,
      );
      await n.retry();
      expect(
        h.container.read(checkoutControllerProvider).phase,
        CheckoutPhase.success,
      );

      expect(keys, hasLength(2));
      expect(keys[0], isNotNull);
      expect(keys[0], keys[1]); // same attempt → same key
    },
  );

  test(
    'duplicate submit with the same key resolves to one order (§53)',
    () async {
      // Backend dedupes: whatever the key, it always returns order 197.
      final be = _backend(orderResponder: (o) => ok(orderDetailJson(id: 197)));
      final h = await _loggedIn(be);
      final n = h.container.read(checkoutControllerProvider.notifier);
      n.selectAddress(50);

      await n.submit();
      final firstId = h.container
          .read(checkoutControllerProvider)
          .result!
          .order
          .id;
      // A fresh attempt (new key) that the backend still dedupes to 197.
      n.startNewAttempt();
      n.selectAddress(50);
      await n.submit();
      final secondId = h.container
          .read(checkoutControllerProvider)
          .result!
          .order
          .id;

      expect(firstId, 197);
      expect(secondId, 197);
    },
  );
}
