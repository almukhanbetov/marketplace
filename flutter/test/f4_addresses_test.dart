import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';
import 'package:nova_marketplace/features/addresses/application/addresses_controller.dart';
import 'package:nova_marketplace/features/addresses/data/address_models.dart';
import 'package:nova_marketplace/features/addresses/data/address_repository.dart';

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
  group('AddressModel / AddressInput', () {
    test('model parses snake_case fields', () {
      final a = AddressModel.fromJson(addressJson());
      expect(a.city, 'Алматы');
      expect(a.postalCode, '050000');
      expect(a.isDefault, isTrue);
      expect(a.oneLine, 'ул. Достык, 89, кв. 12');
    });

    test('input omits blank optionals but always sends is_default', () {
      final json = const AddressInput(
        city: ' Астана ',
        street: 'пр. Абая',
        house: '10',
      ).toJson();
      expect(json.containsKey('title'), isFalse);
      expect(json.containsKey('apartment'), isFalse);
      expect(json.containsKey('postal_code'), isFalse);
      expect(json['city'], 'Астана'); // trimmed
      expect(json['is_default'], false);
    });
  });

  group('AddressRepository', () {
    test('create POSTs the input', () async {
      final adapter = FakeAdapter((o, i) => ok(addressJson(id: 9)));
      final a = await AddressRepository(
        _client(adapter),
      ).create(const AddressInput(city: 'A', street: 'B', house: '1'));
      expect(a.id, 9);
      expect(adapter.received.single.method, 'POST');
      expect(adapter.received.single.path, endsWith('/me/addresses'));
    });

    test('update PUTs /me/addresses/:id', () async {
      final adapter = FakeAdapter((o, i) => ok(addressJson(id: 3)));
      await AddressRepository(
        _client(adapter),
      ).update(3, const AddressInput(city: 'A', street: 'B', house: '1'));
      expect(adapter.received.single.method, 'PUT');
      expect(adapter.received.single.path, endsWith('/me/addresses/3'));
    });

    test('setDefault PATCHes /me/addresses/:id/default', () async {
      final adapter = FakeAdapter((o, i) => ok(addressJson(id: 3)));
      await AddressRepository(_client(adapter)).setDefault(3);
      expect(adapter.received.single.method, 'PATCH');
      expect(adapter.received.single.path, endsWith('/me/addresses/3/default'));
    });

    test('delete DELETEs /me/addresses/:id', () async {
      final adapter = FakeAdapter((o, i) => ok(const {}));
      await AddressRepository(_client(adapter)).delete(3);
      expect(adapter.received.single.method, 'DELETE');
      expect(adapter.received.single.path, endsWith('/me/addresses/3'));
    });
  });

  group('AddressesController', () {
    Future<F4Container> loggedIn(MeBackend be) async {
      final h = await F4Container.create(backend: be);
      h.container.listen(addressesControllerProvider, (_, _) {});
      await h.settleAuth();
      await h.login();
      await pumpUntil(
        () =>
            h.container.read(addressesControllerProvider).status ==
            AddressesStatus.loaded,
      );
      return h;
    }

    test('loads the list after login', () async {
      final be = MeBackend()
        ..on(
          'GET /me/addresses',
          (o) =>
              okRaw([addressJson(id: 1), addressJson(id: 2, isDefault: false)]),
        );
      final h = await loggedIn(be);
      final st = h.container.read(addressesControllerProvider);
      expect(st.items, hasLength(2));
      expect(st.defaultAddress?.id, 1);
    });

    test('create re-reads the list from the backend (§40)', () async {
      var list = <Map<String, dynamic>>[addressJson(id: 1)];
      final be = MeBackend()
        ..on('GET /me/addresses', (o) => okRaw(list))
        ..on('POST /me/addresses', (o) {
          list = [addressJson(id: 1), addressJson(id: 2, isDefault: false)];
          return ok(addressJson(id: 2, isDefault: false));
        });
      final h = await loggedIn(be);
      await h.container
          .read(addressesControllerProvider.notifier)
          .create(const AddressInput(city: 'A', street: 'B', house: '1'));
      expect(h.container.read(addressesControllerProvider).items, hasLength(2));
      // one GET on login + one GET after the mutation
      expect(h.backend.countOf('GET', '/me/addresses'), 2);
    });

    test(
      'setDefault reflects the single-default invariant from Postgres',
      () async {
        var list = <Map<String, dynamic>>[
          addressJson(id: 1, isDefault: true),
          addressJson(id: 2, isDefault: false),
        ];
        final be = MeBackend()
          ..on('GET /me/addresses', (o) => okRaw(list))
          ..on('PATCH /me/addresses/2/default', (o) {
            list = [
              addressJson(id: 1, isDefault: false),
              addressJson(id: 2, isDefault: true),
            ];
            return ok(addressJson(id: 2, isDefault: true));
          });
        final h = await loggedIn(be);
        await h.container
            .read(addressesControllerProvider.notifier)
            .setDefault(2);
        final st = h.container.read(addressesControllerProvider);
        expect(st.defaultAddress?.id, 2);
        expect(st.items.where((a) => a.isDefault), hasLength(1));
      },
    );

    test('delete removes the address', () async {
      var list = <Map<String, dynamic>>[
        addressJson(id: 1),
        addressJson(id: 2, isDefault: false),
      ];
      final be = MeBackend()
        ..on('GET /me/addresses', (o) => okRaw(list))
        ..on('DELETE /me/addresses/2', (o) {
          list = [addressJson(id: 1)];
          return ok(const {});
        });
      final h = await loggedIn(be);
      await h.container.read(addressesControllerProvider.notifier).delete(2);
      expect(h.container.read(addressesControllerProvider).items, hasLength(1));
    });

    test('a failed mutation rethrows and keeps the old list', () async {
      final be = MeBackend()
        ..on('GET /me/addresses', (o) => okRaw([addressJson(id: 1)]))
        ..on(
          'POST /me/addresses',
          (o) => jsonBody(422, {
            'error': {'code': 'VALIDATION_ERROR', 'message': 'bad'},
          }),
        );
      final h = await loggedIn(be);
      await expectLater(
        h.container
            .read(addressesControllerProvider.notifier)
            .create(const AddressInput(city: '', street: '', house: '')),
        throwsA(isA<ApiException>()),
      );
      expect(h.container.read(addressesControllerProvider).items, hasLength(1));
    });

    test('logout clears addresses in memory', () async {
      final be = MeBackend()
        ..on('GET /me/addresses', (o) => okRaw([addressJson(id: 1)]));
      final h = await loggedIn(be);
      await h.logout();
      await pumpUntil(
        () =>
            h.container.read(addressesControllerProvider).status ==
            AddressesStatus.loggedOut,
      );
      expect(h.container.read(addressesControllerProvider).items, isEmpty);
    });
  });
}
