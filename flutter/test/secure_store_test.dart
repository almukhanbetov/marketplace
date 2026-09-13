import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/auth/auth_tokens.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';

import 'support/test_harness.dart';

void main() {
  test('FakeSecureStore save / read / delete contract', () async {
    final s = FakeSecureStore();
    expect(await s.readRefreshToken(), isNull);

    await s.writeRefreshToken('r1');
    expect(await s.readRefreshToken(), 'r1');

    final exp = DateTime.utc(2999);
    await s.writeRefreshExpiry(exp);
    expect(await s.readRefreshExpiry(), exp);

    await s.deleteRefreshToken();
    expect(await s.readRefreshToken(), isNull);
    expect(await s.readRefreshExpiry(), exp); // delete token != clear all

    await s.clear();
    expect(await s.readRefreshExpiry(), isNull);
  });

  test(
    'TokenStore keeps the access token in memory only, refresh in store',
    () async {
      final secure = FakeSecureStore();
      final ts = TokenStore(secure);

      await ts.persist(
        AuthTokens(
          accessToken: 'ACC',
          accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
          refreshToken: 'REF',
          refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      );

      expect(ts.accessToken, 'ACC');
      expect(ts.hasValidAccessToken, isTrue);
      expect(await secure.readRefreshToken(), 'REF');
      expect(await ts.hasRefreshToken(), isTrue);

      await ts.clear();
      expect(ts.accessToken, isNull);
      expect(await secure.readRefreshToken(), isNull);
      expect(secure.clearCount, 1);
    },
  );

  test(
    'persist ignores an empty refresh token (e.g. from a web-shape body)',
    () async {
      final secure = FakeSecureStore();
      final ts = TokenStore(secure);
      await ts.persist(
        AuthTokens(
          accessToken: 'ACC',
          accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
          refreshToken: '',
        ),
      );
      expect(ts.accessToken, 'ACC');
      expect(await secure.readRefreshToken(), isNull);
    },
  );
}
