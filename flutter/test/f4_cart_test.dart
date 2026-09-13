import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/cart/application/cart_controller.dart';
import 'package:nova_marketplace/features/cart/data/cart_models.dart';
import 'package:nova_marketplace/features/cart/data/cart_repository.dart';

import 'support/f4_fixtures.dart';
import 'support/f4_harness.dart';
import 'support/fake_dio.dart';
import 'support/test_harness.dart';

ApiClient _client(FakeAdapter a) => ApiClient(
  tokenStore: TokenStore(FakeSecureStore()),
  tokenRefresher: const NoopTokenRefresher(),
  dio: Dio()..httpClientAdapter = a,
);

void main() {
  group('CartModel', () {
    test('parses items, summary and line totals', () {
      final m = CartModel.fromJson(
        cartJson(
          items: [
            cartItemJson(
              id: 1,
              quantity: 2,
              price: '100.00',
              lineTotal: '200.00',
            ),
          ],
          subtotal: '200.00',
        ),
      );
      expect(m.items.single.lineTotal, '200.00');
      expect(m.itemCount, 2);
      expect(m.subtotal, '200.00');
    });

    test('cart identity is seller_offer_id — same product, two sellers, '
        'two distinct lines (§15/§76)', () {
      final m = CartModel.fromJson(
        cartJson(
          items: [
            cartItemJson(
              id: 10,
              sellerOfferId: 100,
              productId: 1,
              sellerId: 1,
              sellerName: 'TechStore',
            ),
            cartItemJson(
              id: 11,
              sellerOfferId: 200,
              productId: 1,
              sellerId: 4,
              sellerName: 'GadgetPro',
            ),
          ],
        ),
      );
      expect(m.items, hasLength(2));
      expect(m.items.map((i) => i.product.id).toSet(), {1});
      expect(m.items.map((i) => i.sellerOfferId).toSet(), {100, 200});

      final groups = m.groupedBySeller;
      expect(groups, hasLength(2));
      expect(groups.map((g) => g.seller.name), ['TechStore', 'GadgetPro']);
    });

    test('atStockLimit reflects available_quantity', () {
      final atLimit = CartItemModel.fromJson(
        cartItemJson(quantity: 5, availableQuantity: 5),
      );
      final below = CartItemModel.fromJson(
        cartItemJson(quantity: 2, availableQuantity: 5),
      );
      expect(atLimit.atStockLimit, isTrue);
      expect(below.atStockLimit, isFalse);
    });
  });

  group('CartRepository', () {
    test('addItem sends {seller_offer_id, quantity} only — no price', () async {
      late Map<String, dynamic> body;
      final adapter = FakeAdapter((o, i) {
        body = Map<String, dynamic>.from(o.data as Map);
        return ok(cartJson(items: [cartItemJson()]));
      });
      await CartRepository(_client(adapter)).addItem(42, 3);
      expect(body.keys.toSet(), {'seller_offer_id', 'quantity'});
      expect(body['seller_offer_id'], 42);
      expect(body['quantity'], 3);
      expect(body.containsKey('price'), isFalse);
    });

    test('updateQuantity PATCHes the cart-item id', () async {
      final adapter = FakeAdapter((o, i) => ok(cartJson()));
      await CartRepository(_client(adapter)).updateQuantity(881, 4);
      expect(adapter.received.single.method, 'PATCH');
      expect(adapter.received.single.path, endsWith('/me/cart/items/881'));
      expect((adapter.received.single.data as Map)['quantity'], 4);
    });

    test('clear DELETEs the bulk /me/cart endpoint', () async {
      final adapter = FakeAdapter((o, i) => ok(cartJson()));
      await CartRepository(_client(adapter)).clear();
      expect(adapter.received.single.method, 'DELETE');
      expect(adapter.received.single.path, endsWith('/me/cart'));
    });

    test('INSUFFICIENT_STOCK surfaces as ApiException', () async {
      final adapter = FakeAdapter(
        (o, i) => jsonBody(409, {
          'error': {'code': 'INSUFFICIENT_STOCK', 'message': 'Only 5 in stock'},
        }),
      );
      await expectLater(
        CartRepository(_client(adapter)).addItem(1, 999),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'INSUFFICIENT_STOCK',
          ),
        ),
      );
    });
  });

  group('CartController', () {
    Future<F4Container> loggedIn(MeBackend be) async {
      final h = await F4Container.create(backend: be);
      h.container.listen(cartControllerProvider, (_, _) {});
      h.container.listen(cartBadgeCountProvider, (_, _) {});
      await h.settleAuth();
      await h.login();
      await pumpUntil(
        () =>
            h.container.read(cartControllerProvider).status ==
            CartStatus.loaded,
      );
      return h;
    }

    test('loads after login; badge count reflects item_count', () async {
      final be = MeBackend()
        ..on(
          'GET /me/cart',
          (o) => ok(cartJson(items: [cartItemJson(quantity: 3)], itemCount: 3)),
        );
      final h = await loggedIn(be);
      expect(h.container.read(cartControllerProvider).cart.items, hasLength(1));
      expect(h.container.read(cartBadgeCountProvider), 3);
    });

    test('addOffer posts and replaces state with the backend cart', () async {
      var cart = cartJson();
      final be = MeBackend()
        ..on('GET /me/cart', (o) => ok(cart))
        ..on('POST /me/cart/items', (o) {
          cart = cartJson(items: [cartItemJson(quantity: 1)], itemCount: 1);
          return ok(cart);
        });
      final h = await loggedIn(be);
      await h.container.read(cartControllerProvider.notifier).addOffer(1);
      expect(h.container.read(cartControllerProvider).cart.itemCount, 1);
      expect(h.container.read(cartBadgeCountProvider), 1);
    });

    test('adding the same offer id increments the existing line', () async {
      var qty = 1;
      final be = MeBackend()
        ..on(
          'GET /me/cart',
          (o) => ok(
            cartJson(
              items: [cartItemJson(quantity: qty)],
              itemCount: qty,
            ),
          ),
        )
        ..on('POST /me/cart/items', (o) {
          qty += 1; // backend merges by seller_offer_id
          return ok(
            cartJson(
              items: [cartItemJson(quantity: qty)],
              itemCount: qty,
            ),
          );
        });
      final h = await loggedIn(be);
      await h.container.read(cartControllerProvider.notifier).addOffer(1);
      final st = h.container.read(cartControllerProvider);
      expect(st.cart.items, hasLength(1));
      expect(st.cart.items.single.quantity, 2);
    });

    test('setQuantity(<1) is a no-op (no PATCH, no zero)', () async {
      final be = MeBackend()
        ..on(
          'GET /me/cart',
          (o) => ok(cartJson(items: [cartItemJson(id: 5, quantity: 1)])),
        );
      final h = await loggedIn(be);
      await h.container.read(cartControllerProvider.notifier).setQuantity(5, 0);
      expect(h.backend.countOf('PATCH', '/me/cart/items/5'), 0);
    });

    test('remove drops the line', () async {
      var cart = cartJson(
        items: [cartItemJson(id: 5, quantity: 1)],
        itemCount: 1,
      );
      final be = MeBackend()
        ..on('GET /me/cart', (o) => ok(cart))
        ..on('DELETE /me/cart/items/5', (o) {
          cart = cartJson();
          return ok(cart);
        });
      final h = await loggedIn(be);
      await h.container.read(cartControllerProvider.notifier).remove(5);
      expect(h.container.read(cartControllerProvider).cart.isEmpty, isTrue);
      expect(h.container.read(cartBadgeCountProvider), 0);
    });

    test('clear empties the cart', () async {
      var cart = cartJson(
        items: [cartItemJson(id: 5), cartItemJson(id: 6, sellerOfferId: 2)],
        itemCount: 2,
      );
      final be = MeBackend()
        ..on('GET /me/cart', (o) => ok(cart))
        ..on('DELETE /me/cart', (o) {
          cart = cartJson();
          return ok(cart);
        });
      final h = await loggedIn(be);
      await h.container.read(cartControllerProvider.notifier).clear();
      expect(h.container.read(cartControllerProvider).cart.isEmpty, isTrue);
    });

    test('INSUFFICIENT_STOCK on add does not corrupt the cart (§77)', () async {
      final be = MeBackend()
        ..on(
          'GET /me/cart',
          (o) => ok(
            cartJson(items: [cartItemJson(id: 5, quantity: 1)], itemCount: 1),
          ),
        )
        ..on(
          'POST /me/cart/items',
          (o) => jsonBody(409, {
            'error': {
              'code': 'INSUFFICIENT_STOCK',
              'message': 'Only 5 in stock',
            },
          }),
        );
      final h = await loggedIn(be);
      await expectLater(
        h.container
            .read(cartControllerProvider.notifier)
            .addOffer(1, quantity: 999),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'INSUFFICIENT_STOCK',
          ),
        ),
      );
      final st = h.container.read(cartControllerProvider);
      expect(st.cart.items, hasLength(1));
      expect(st.cart.items.single.quantity, 1);
      expect(st.adding, isFalse);
    });

    test('logout clears the cart in memory; login reloads from DB', () async {
      var serverCart = cartJson(
        items: [cartItemJson(id: 5, quantity: 2)],
        itemCount: 2,
      );
      final be = MeBackend()..on('GET /me/cart', (o) => ok(serverCart));
      final h = await loggedIn(be);
      expect(h.container.read(cartBadgeCountProvider), 2);

      await h.logout();
      await pumpUntil(
        () =>
            h.container.read(cartControllerProvider).status ==
            CartStatus.loggedOut,
      );
      expect(h.container.read(cartControllerProvider).cart.isEmpty, isTrue);
      expect(h.container.read(cartBadgeCountProvider), 0);
      expect(h.backend.countOf('DELETE', '/me/cart'), 0);

      // DB still has the cart — a fresh login restores it.
      await h.login();
      await pumpUntil(
        () =>
            h.container.read(cartControllerProvider).status ==
            CartStatus.loaded,
      );
      expect(h.container.read(cartBadgeCountProvider), 2);
    });
  });
}
