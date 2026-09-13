import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_providers.dart';
import '../errors/api_exception.dart';
import 'auth_repository.dart';
import 'auth_requests.dart';
import 'auth_tokens.dart';
import 'auth_user.dart';
import 'token_store.dart';

/// Talks to the Go auth API over the shared [ApiClient] and keeps
/// [TokenStore] in sync (access token → memory, refresh token → keychain).
/// Owns nothing about UI state — that's `AuthController`.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  /// Single-flight refresh: `AuthController.restoreSession()` and the Dio
  /// 401 interceptor can both ask for a refresh at once — they share one
  /// in-flight call so the refresh token rotates exactly once, never in a
  /// race (Stage F2 §28).
  Future<AuthTokens?>? _refreshInFlight;

  @override
  Future<AuthSession> register(RegisterRequest request) async {
    final data = await _api.post('/auth/register', body: request.toJson());
    return _sessionFrom(data as Map);
  }

  @override
  Future<AuthSession> login(LoginRequest request) async {
    final data = await _api.post('/auth/login', body: request.toJson());
    return _sessionFrom(data as Map);
  }

  Future<AuthSession> _sessionFrom(Map<dynamic, dynamic> data) async {
    final map = Map<String, dynamic>.from(data);
    final tokens = AuthTokens.fromJson(map);
    await _tokens.persist(tokens);
    final userJson = map['user'];
    if (userJson is! Map) throw ApiException.parse();
    return AuthSession(
      tokens: tokens,
      user: AuthUser.fromJson(Map<String, dynamic>.from(userJson)),
    );
  }

  @override
  Future<AuthUser> me() async {
    final data = await _api.get('/auth/me');
    return AuthUser.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<AuthTokens?> refresh() {
    return _refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<AuthTokens?> _refresh() async {
    final stored = await _tokens.readRefreshToken();
    if (stored == null || stored.isEmpty) return null;

    try {
      final data = await _api.post(
        '/auth/refresh',
        body: {'refresh_token': stored},
      );
      final rotated = AuthTokens.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
      await _tokens.persist(rotated);
      return rotated;
    } on ApiException catch (e) {
      // Definitively gone → wipe local creds and report "no session".
      if (e.kind == ApiErrorKind.unauthorized ||
          e.kind == ApiErrorKind.forbidden ||
          e.code == 'SESSION_EXPIRED') {
        await _tokens.clear();
        return null;
      }
      // Transient (offline / timeout / 5xx) → keep the refresh token,
      // rethrow so the caller can show a service error and retry later.
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final stored = await _tokens.readRefreshToken();
    try {
      if (stored != null && stored.isNotEmpty) {
        await _api.post('/auth/logout', body: {'refresh_token': stored});
      }
    } on ApiException {
      // Offline logout still completes locally; the server session will
      // lapse at its TTL if the revoke never landed (Stage F2 §39).
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<void> logoutAll() async {
    try {
      await _api.post('/auth/logout-all');
    } on ApiException {
      // Same tolerance as logout().
    } finally {
      await _tokens.clear();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});
