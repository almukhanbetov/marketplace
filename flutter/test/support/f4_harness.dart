import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova_marketplace/core/api/api_client.dart';
import 'package:nova_marketplace/core/api/api_providers.dart';
import 'package:nova_marketplace/core/api/token_refresher.dart';
import 'package:nova_marketplace/core/auth/auth_controller.dart';
import 'package:nova_marketplace/core/auth/auth_repository.dart';
import 'package:nova_marketplace/core/auth/auth_repository_impl.dart';
import 'package:nova_marketplace/core/auth/auth_state.dart';
import 'package:nova_marketplace/core/auth/auth_user.dart';
import 'package:nova_marketplace/core/auth/token_store.dart';
import 'package:nova_marketplace/core/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_dio.dart';
import 'test_harness.dart';

/// A scripted backend for the F4 `/me/*` endpoints. Register handlers by
/// `"METHOD /path"` — the path is matched by suffix so query strings and
/// the base URL don't matter.
class MeBackend {
  final List<({String method, String path})> calls = [];
  final Map<String, ResponseBody Function(RequestOptions o)> _routes = {};

  void on(String key, ResponseBody Function(RequestOptions o) handler) {
    _routes[key] = handler;
  }

  ResponseBody handle(RequestOptions o, int _) {
    final method = o.method.toUpperCase();
    calls.add((method: method, path: o.path));
    for (final entry in _routes.entries) {
      final parts = entry.key.split(' ');
      if (parts[0].toUpperCase() == method && o.path.endsWith(parts[1])) {
        return entry.value(o);
      }
    }
    // Auth endpoints hit during login/refresh are handled by the fake repo,
    // never reach here. Anything unexpected → 404 so the test fails loudly.
    return notFoundBody('NO_ROUTE');
  }

  int countOf(String method, String pathSuffix) => calls
      .where((c) => c.method == method && c.path.endsWith(pathSuffix))
      .length;
}

/// Container wired with a fake [ApiClient] (driven by [backend]) and a
/// fake [AuthRepository]. Starts unauthenticated; call [login].
class F4Container {
  F4Container._(this.container, this.backend);

  final ProviderContainer container;
  final MeBackend backend;

  static Future<F4Container> create({
    MeBackend? backend,
    AuthUser? user,
  }) async {
    final be = backend ?? MeBackend();
    final adapter = FakeAdapter(be.handle);
    final client = ApiClient(
      tokenStore: TokenStore(FakeSecureStore()),
      tokenRefresher: const NoopTokenRefresher(),
      dio: Dio()..httpClientAdapter = adapter,
    );
    final u = user ?? fakeUser();
    final authRepo = FakeAuthRepository(
      onLogin: (_) async => AuthSession(tokens: fakeTokens(), user: u),
      onLogout: () async {},
    );
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authRepositoryProvider.overrideWithValue(authRepo),
        secureStoreProvider.overrideWithValue(FakeSecureStore()),
      ],
    );
    addTearDown(c.dispose);
    return F4Container._(c, be);
  }

  Future<void> login() async {
    await container
        .read(authControllerProvider.notifier)
        .login(identifier: 'aigerim@example.com', password: 'pw');
  }

  Future<void> logout() async {
    await container.read(authControllerProvider.notifier).logout();
  }

  Future<void> settleAuth() async {
    for (var i = 0; i < 100; i++) {
      final st = container.read(authControllerProvider).status;
      if (st != AuthStatus.unknown && st != AuthStatus.restoring) return;
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }
}

/// Pump microtasks/timers until [test] passes or we give up.
Future<void> pumpUntil(bool Function() test, {int tries = 600}) async {
  for (var i = 0; i < tries; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
