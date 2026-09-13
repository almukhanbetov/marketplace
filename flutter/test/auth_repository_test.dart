import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/auth/auth_repository_impl.dart';
import 'package:nova_marketplace/core/auth/auth_requests.dart';
import 'package:nova_marketplace/core/auth/auth_tokens.dart';
import 'package:nova_marketplace/core/auth/auth_user.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';

import 'support/fake_dio.dart';
import 'support/test_harness.dart';

void main() {
  group('request bodies', () {
    test('LoginRequest routes an @ identifier to email, else phone', () {
      expect(
        const LoginRequest(identifier: 'a@b.com', password: 'p').toJson(),
        {'email': 'a@b.com', 'password': 'p'},
      );
      expect(
        const LoginRequest(identifier: '+77010000001', password: 'p').toJson(),
        {'phone': '+77010000001', 'password': 'p'},
      );
    });

    test('RegisterRequest omits blank optional fields', () {
      expect(
        const RegisterRequest(
          fullName: 'A B',
          password: 'p',
          email: 'a@b.c',
        ).toJson(),
        {'full_name': 'A B', 'password': 'p', 'email': 'a@b.c'},
      );
    });
  });

  group('response parsing', () {
    test('AuthTokens.fromJson reads the mobile shape', () {
      final t = AuthTokens.fromJson({
        'access_token': 'AAA',
        'access_expires_at': '2999-01-01T00:00:00Z',
        'refresh_token': 'RRR',
        'refresh_expires_at': '2999-02-01T00:00:00Z',
      });
      expect(t.accessToken, 'AAA');
      expect(t.refreshToken, 'RRR');
      expect(t.refreshTokenExpiresAt!.year, 2999);
      expect(t.isAccessTokenExpired, isFalse);
    });

    test('AuthUser.fromJson handles UserDetail with seller_id and counts', () {
      final u = AuthUser.fromJson({
        'id': 7,
        'email': 's@n.kz',
        'phone': null,
        'full_name': 'Seller',
        'role': 'seller',
        'is_active': true,
        'seller_id': 4,
        'orders_count': 2,
      });
      expect(u.isSeller, isTrue);
      expect(u.hasSellerAccount, isTrue);
      expect(u.sellerId, 4);
      expect(u.ordersCount, 2);
    });
  });

  group('AuthRepositoryImpl', () {
    ApiClient client(FakeAdapter adapter) => ApiClient(
      tokenStore: TokenStore(FakeSecureStore()),
      tokenRefresher: CountingRefresher(),
      dio: Dio()..httpClientAdapter = adapter,
    );

    test('login persists tokens and returns the user', () async {
      final store = FakeSecureStore();
      final adapter = FakeAdapter(
        (o, i) => ok({
          'access_token': 'A',
          'access_expires_at': '2999-01-01T00:00:00Z',
          'refresh_token': 'R',
          'refresh_expires_at': '2999-01-01T00:00:00Z',
          'user': {
            'id': 1,
            'full_name': 'C',
            'role': 'customer',
            'is_active': true,
          },
        }),
      );
      final ts = TokenStore(store);
      final repo = AuthRepositoryImpl(
        ApiClient(
          tokenStore: ts,
          tokenRefresher: CountingRefresher(),
          dio: Dio()..httpClientAdapter = adapter,
        ),
        ts,
      );

      final session = await repo.login(
        const LoginRequest(identifier: 'c@x.z', password: 'passw0rd'),
      );
      expect(session.user.fullName, 'C');
      expect(await store.readRefreshToken(), 'R');
      expect(ts.accessToken, 'A');
    });

    test('refresh with no stored token returns null (no HTTP call)', () async {
      final adapter = FakeAdapter((o, i) => ok({}));
      final ts = TokenStore(FakeSecureStore());
      final repo = AuthRepositoryImpl(client(adapter), ts);
      expect(await repo.refresh(), isNull);
      expect(adapter.calls, 0);
    });

    test('refresh: 401 clears the stored token and returns null', () async {
      final store = FakeSecureStore(refreshToken: 'old');
      final adapter = FakeAdapter((o, i) => unauthorizedBody());
      final ts = TokenStore(store);
      final repo = AuthRepositoryImpl(
        ApiClient(
          tokenStore: ts,
          tokenRefresher: CountingRefresher(),
          dio: Dio()..httpClientAdapter = adapter,
        ),
        ts,
      );
      expect(await repo.refresh(), isNull);
      expect(await store.readRefreshToken(), isNull);
    });

    test('refresh: a 5xx is transient — token kept, throws', () async {
      final store = FakeSecureStore(refreshToken: 'keep');
      final adapter = FakeAdapter(
        (o, i) => jsonBody(503, {
          'error': {'code': 'INTERNAL', 'message': 'x'},
        }),
      );
      final ts = TokenStore(store);
      final repo = AuthRepositoryImpl(
        ApiClient(
          tokenStore: ts,
          tokenRefresher: CountingRefresher(),
          dio: Dio()..httpClientAdapter = adapter,
        ),
        ts,
      );
      await expectLater(repo.refresh(), throwsA(isA<ApiException>()));
      expect(await store.readRefreshToken(), 'keep');
    });

    test('refresh is single-flight', () async {
      final store = FakeSecureStore(refreshToken: 'old');
      var httpCalls = 0;
      final adapter = FakeAdapter((o, i) {
        httpCalls++;
        return ok({
          'access_token': 'A$i',
          'access_expires_at': '2999-01-01T00:00:00Z',
          'refresh_token': 'R$i',
          'refresh_expires_at': '2999-01-01T00:00:00Z',
        });
      });
      final ts = TokenStore(store);
      final repo = AuthRepositoryImpl(
        ApiClient(
          tokenStore: ts,
          tokenRefresher: CountingRefresher(),
          dio: Dio()..httpClientAdapter = adapter,
        ),
        ts,
      );

      await Future.wait([repo.refresh(), repo.refresh(), repo.refresh()]);
      expect(httpCalls, 1);
    });
  });
}
