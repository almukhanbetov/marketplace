import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_repository_impl.dart';

/// Contract the [ApiClient]'s 401-interceptor calls to obtain a fresh
/// access token.
///
/// The implementation MUST:
///  - de-duplicate concurrent calls (one in-flight refresh shared by all
///    waiting requests) — enforced in `AuthRepositoryImpl.refresh()`,
///  - persist the rotated refresh token,
///  - return `null` (never throw) when the session is unrecoverable, after
///    clearing local credentials and signalling a forced logout.
abstract interface class TokenRefresher {
  /// Returns the new access token, or `null` if the session is gone.
  Future<String?> refresh();

  /// Called by the interceptor when refresh returned `null` — lets the
  /// auth layer flip global state to "logged out" and route to /login.
  void onSessionExpired();
}

/// No session yet / tests that don't exercise refresh: a 401 fails through.
class NoopTokenRefresher implements TokenRefresher {
  const NoopTokenRefresher();

  @override
  Future<String?> refresh() async => null;

  @override
  void onSessionExpired() {}
}

/// Real refresher: delegates to `AuthRepository.refresh()` (which owns the
/// single-flight guard + rotation + keychain persistence) and, on a
/// definitive failure, tells `AuthController` to log the user out.
///
/// It reads its collaborators lazily via [ref] at call time — never at
/// construction — so there is no provider cycle with `apiClientProvider`
/// (which builds this). `refresh()` swallows every error to `null`: a
/// transient network failure just means "this request's 401 stands", and
/// the original request surfaces its own error to the caller.
class RefTokenRefresher implements TokenRefresher {
  RefTokenRefresher(this._ref);

  final Ref _ref;

  @override
  Future<String?> refresh() async {
    try {
      final tokens = await _ref.read(authRepositoryProvider).refresh();
      return tokens?.accessToken;
    } on Object {
      return null;
    }
  }

  @override
  void onSessionExpired() {
    _ref.read(authControllerProvider.notifier).forceLoggedOut();
  }
}
