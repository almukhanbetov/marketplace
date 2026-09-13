import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/favorites/application/favorites_controller.dart';
import 'package:nova_marketplace/features/favorites/data/favorite_repository.dart';

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
  group('FavoriteRepository', () {
    test('list() parses the product-card shape', () async {
      final adapter = FakeAdapter(
        (o, i) => okRaw([favoriteCardJson(id: 1), favoriteCardJson(id: 2)]),
      );
      final items = await FavoriteRepository(_client(adapter)).list();
      expect(items.map((p) => p.id), [1, 2]);
      expect(items.first.price, '620000.00');
      expect(adapter.received.single.method, 'GET');
      expect(adapter.received.single.path, endsWith('/me/favorites'));
    });

    test('add() POSTs /me/favorites/:id', () async {
      final adapter = FakeAdapter((o, i) => ok({'favorited': true}));
      await FavoriteRepository(_client(adapter)).add(7);
      expect(adapter.received.single.method, 'POST');
      expect(adapter.received.single.path, endsWith('/me/favorites/7'));
    });

    test('remove() DELETEs /me/favorites/:id', () async {
      final adapter = FakeAdapter((o, i) => ok({'favorited': false}));
      await FavoriteRepository(_client(adapter)).remove(7);
      expect(adapter.received.single.method, 'DELETE');
      expect(adapter.received.single.path, endsWith('/me/favorites/7'));
    });
  });

  group('FavoritesController', () {
    test('loads from the backend after login', () async {
      final be = MeBackend()
        ..on(
          'GET /me/favorites',
          (o) => okRaw([favoriteCardJson(id: 1), favoriteCardJson(id: 5)]),
        );
      final h = await F4Container.create(backend: be);
      h.container.listen(favoritesControllerProvider, (_, _) {});
      await h.settleAuth();
      await h.login();
      await pumpUntil(
        () =>
            h.container.read(favoritesControllerProvider).status ==
            FavStatus.loaded,
      );
      final st = h.container.read(favoritesControllerProvider);
      expect(st.ids, {1, 5});
      expect(st.items, hasLength(2));
    });

    test('toggle add is optimistic and calls the backend', () async {
      var added = 0;
      final be = MeBackend()
        ..on('GET /me/favorites', (o) => okRaw(const []))
        ..on('POST /me/favorites/9', (o) {
          added++;
          return ok({'favorited': true});
        });
      final h = await F4Container.create(backend: be);
      h.container.listen(favoritesControllerProvider, (_, _) {});
      await h.settleAuth();
      await h.login();
      await pumpUntil(
        () =>
            h.container.read(favoritesControllerProvider).status ==
            FavStatus.loaded,
      );

      final future = h.container
          .read(favoritesControllerProvider.notifier)
          .toggle(9, known: favoriteModel(id: 9));
      // optimistic: id present before the network call resolves
      expect(h.container.read(favoritesControllerProvider).ids, contains(9));
      await future;
      expect(added, 1);
      expect(h.container.read(favoritesControllerProvider).ids, contains(9));
    });

    test('toggle remove drops the id and calls DELETE', () async {
      var removed = 0;
      final be = MeBackend()
        ..on('GET /me/favorites', (o) => okRaw([favoriteCardJson(id: 3)]))
        ..on('DELETE /me/favorites/3', (o) {
          removed++;
          return ok({'favorited': false});
        });
      final h = await F4Container.create(backend: be);
      h.container.listen(favoritesControllerProvider, (_, _) {});
      await h.settleAuth();
      await h.login();
      await pumpUntil(
        () => h.container.read(favoritesControllerProvider).ids.contains(3),
      );

      await h.container
          .read(favoritesControllerProvider.notifier)
          .toggle(3, known: favoriteModel(id: 3));
      expect(removed, 1);
      expect(
        h.container.read(favoritesControllerProvider).ids,
        isNot(contains(3)),
      );
      expect(h.container.read(favoritesControllerProvider).items, isEmpty);
    });

    test('failed toggle rolls back and rethrows', () async {
      final be = MeBackend()
        ..on('GET /me/favorites', (o) => okRaw(const []))
        ..on(
          'POST /me/favorites/9',
          (o) => jsonBody(500, {
            'error': {'code': 'BOOM', 'message': 'no'},
          }),
        );
      final h = await F4Container.create(backend: be);
      h.container.listen(favoritesControllerProvider, (_, _) {});
      await h.settleAuth();
      await h.login();
      await pumpUntil(
        () =>
            h.container.read(favoritesControllerProvider).status ==
            FavStatus.loaded,
      );

      await expectLater(
        h.container
            .read(favoritesControllerProvider.notifier)
            .toggle(9, known: favoriteModel(id: 9)),
        throwsA(isA<ApiException>()),
      );
      // rolled back
      expect(
        h.container.read(favoritesControllerProvider).ids,
        isNot(contains(9)),
      );
    });

    test('logout clears favorites in memory (no backend DELETE)', () async {
      final be = MeBackend()
        ..on('GET /me/favorites', (o) => okRaw([favoriteCardJson(id: 1)]));
      final h = await F4Container.create(backend: be);
      h.container.listen(favoritesControllerProvider, (_, _) {});
      await h.settleAuth();
      await h.login();
      await pumpUntil(
        () => h.container.read(favoritesControllerProvider).ids.contains(1),
      );

      await h.logout();
      await pumpUntil(
        () =>
            h.container.read(favoritesControllerProvider).status ==
            FavStatus.loggedOut,
      );
      final st = h.container.read(favoritesControllerProvider);
      expect(st.ids, isEmpty);
      expect(st.items, isEmpty);
      // only the initial GET — logout must not touch the backend row
      expect(be.countOf('DELETE', '/me/favorites/1'), 0);
    });
  });
}
