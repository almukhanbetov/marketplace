import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';

import 'support/fake_dio.dart';
import 'support/test_harness.dart';

TokenStore _store(String? access) {
  final ts = TokenStore(FakeSecureStore());
  if (access != null) {
    ts.setAccessToken(access, DateTime.now().add(const Duration(minutes: 10)));
  }
  return ts;
}

/// Builds an [ApiClient] whose [CountingRefresher] shares its [TokenStore]
/// — a successful refresh updates the token the request interceptor
/// re-reads on retry, exactly like the real app.
({ApiClient client, CountingRefresher refresher}) rig({
  required FakeAdapter adapter,
  String? access,
  String? refreshToken = 'refreshed-access',
}) {
  final store = _store(access);
  final refresher = CountingRefresher(token: refreshToken, store: store);
  final client = ApiClient(
    tokenStore: store,
    tokenRefresher: refresher,
    dio: Dio()..httpClientAdapter = adapter,
  );
  return (client: client, refresher: refresher);
}

void main() {
  test(
    'attaches Bearer + X-Client + X-Request-ID to a protected request',
    () async {
      final adapter = FakeAdapter((opts, _) => ok({'ok': true}));
      final r = rig(adapter: adapter, access: 'tok-123');

      await r.client.get('/products');

      final req = adapter.received.single;
      expect(req.headers['Authorization'], 'Bearer tok-123');
      expect(req.headers['X-Client'], 'nova-mobile');
      expect(req.headers['X-Request-ID'], isNotNull);
    },
  );

  test('no Bearer on login/register/refresh/logout; YES on /auth/me', () async {
    final adapter = FakeAdapter((opts, _) => ok({'x': 1}));
    final r = rig(adapter: adapter, access: 'tok-123');

    await r.client.post('/auth/login', body: {'email': 'a', 'password': 'b'});
    await r.client.post('/auth/refresh', body: {'refresh_token': 'x'});
    await r.client.post('/auth/logout', body: {'refresh_token': 'x'});
    await r.client.get('/auth/me');

    final byPath = {for (final o in adapter.received) o.path: o.headers};
    expect(byPath['/auth/login']!.containsKey('Authorization'), isFalse);
    expect(byPath['/auth/refresh']!.containsKey('Authorization'), isFalse);
    expect(byPath['/auth/logout']!.containsKey('Authorization'), isFalse);
    expect(byPath['/auth/me']!['Authorization'], 'Bearer tok-123');
  });

  test(
    '401 on a protected path → one refresh → retry once → success',
    () async {
      final adapter = FakeAdapter(
        (opts, i) => i == 0 ? unauthorizedBody() : ok({'ok': true}),
      );
      final r = rig(
        adapter: adapter,
        access: 'stale',
        refreshToken: 'new-access',
      );

      final data = await r.client.get('/me/cart');
      expect(data, {'ok': true});
      expect(r.refresher.refreshCalls, 1);
      expect(adapter.calls, 2);
      expect(
        adapter.received.last.headers['Authorization'],
        'Bearer new-access',
      );
    },
  );

  test('refresh returns null → onSessionExpired + the 401 surfaces', () async {
    final adapter = FakeAdapter((opts, i) => unauthorizedBody());
    final r = rig(adapter: adapter, access: 'stale', refreshToken: null);

    await expectLater(
      r.client.get('/me/cart'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );
    expect(r.refresher.refreshCalls, 1);
    expect(r.refresher.sessionExpiredCalls, 1);
  });

  test('concurrent 401s share ONE refresh (single-flight)', () async {
    final adapter = FakeAdapter((opts, i) {
      final isRetry = opts.extra['__retried'] == true;
      return isRetry ? ok({'p': opts.path}) : unauthorizedBody();
    });
    final r = rig(
      adapter: adapter,
      access: 'stale',
      refreshToken: 'shared-new',
    );
    r.refresher.delay = const Duration(milliseconds: 40);

    await Future.wait([
      r.client.get('/me/cart'),
      r.client.get('/me/favorites'),
      r.client.get('/me/orders'),
    ]);

    expect(
      r.refresher.refreshCalls,
      1,
      reason: 'refresh must be single-flight',
    );
  });

  test(
    'a 401 from /auth/refresh itself does NOT recurse into refresh',
    () async {
      final adapter = FakeAdapter((opts, i) => unauthorizedBody());
      final r = rig(adapter: adapter, access: 'stale');

      await expectLater(
        r.client.post('/auth/refresh', body: {}),
        throwsA(isA<ApiException>()),
      );
      expect(r.refresher.refreshCalls, 0);
    },
  );
}
