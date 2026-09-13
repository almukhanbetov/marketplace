import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_exception.dart';
import 'auth_repository.dart';
import 'auth_repository_impl.dart';
import 'auth_requests.dart';
import 'auth_state.dart';
import 'token_store.dart';

/// Owns the user-visible [AuthState] and the session lifecycle: silent
/// restore on launch, login / register, logout. It does NOT own transient
/// form state (the login screen tracks its own submit-in-progress / error).
///
/// All network + token work is delegated to [AuthRepository]; this class
/// only decides what the resulting [AuthState] is.
class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repo = ref.watch(authRepositoryProvider);
  late final TokenStore _tokens = ref.watch(tokenStoreProvider);

  @override
  AuthState build() {
    Future.microtask(restoreSession);
    return const AuthState.unknown();
  }

  /// App-start session restore (Stage F2 §26):
  ///  1. no stored refresh token        → unauthenticated
  ///  2. refresh + /me succeed          → authenticated
  ///  3. refresh says session is gone   → clear + unauthenticated
  ///  4. transient failure (offline…)   → unauthenticated + keep token,
  ///                                       flagged so the UI can retry
  Future<void> restoreSession() async {
    try {
      if (!await _tokens.hasRefreshToken()) {
        state = const AuthState.unauthenticated();
        return;
      }
      state = const AuthState.restoring();
      final rotated = await _repo.refresh();
      if (rotated == null) {
        // Repo already cleared local creds for a definitive failure.
        state = const AuthState.unauthenticated();
        return;
      }
      final user = await _repo.me();
      state = AuthState.authenticated(user);
    } on ApiException catch (e) {
      if (_isTransient(e)) {
        // Keep the refresh token — a later retry can still restore.
        state = const AuthState.unauthenticated(restoreFailedTransiently: true);
      } else {
        await _safeClear();
        state = const AuthState.unauthenticated();
      }
    } on Object {
      await _safeClear();
      state = const AuthState.unauthenticated();
    }
  }

  Future<AuthUserRole> login({
    required String identifier,
    required String password,
  }) async {
    final session = await _repo.login(
      LoginRequest(identifier: identifier, password: password),
    );
    state = AuthState.authenticated(session.user);
    return _roleOf(session.user.role);
  }

  Future<AuthUserRole> register({
    String? email,
    String? phone,
    required String fullName,
    required String password,
  }) async {
    final session = await _repo.register(
      RegisterRequest(
        fullName: fullName,
        password: password,
        email: email,
        phone: phone,
      ),
    );
    state = AuthState.authenticated(session.user);
    return _roleOf(session.user.role);
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } finally {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> logoutAll() async {
    try {
      await _repo.logoutAll();
    } finally {
      state = const AuthState.unauthenticated();
    }
  }

  /// Re-run restore after a transient failure (retry button).
  Future<void> retryRestore() => restoreSession();

  /// Called by the API layer's [TokenRefresher.onSessionExpired] hook when
  /// a mid-session refresh fails definitively.
  void forceLoggedOut() {
    _tokens.clearAccessToken();
    state = const AuthState.unauthenticated();
  }

  Future<void> _safeClear() async {
    try {
      await _tokens.clear();
    } on Object {
      // best effort
    }
  }

  static bool _isTransient(ApiException e) =>
      e.kind == ApiErrorKind.network ||
      e.kind == ApiErrorKind.timeout ||
      e.kind == ApiErrorKind.server;

  AuthUserRole _roleOf(String role) => switch (role) {
    'seller' => AuthUserRole.seller,
    'admin' => AuthUserRole.admin,
    _ => AuthUserRole.customer,
  };
}

/// Post-auth landing hint for the caller (login/register screens).
enum AuthUserRole { customer, seller, admin }

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
