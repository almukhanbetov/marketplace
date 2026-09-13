import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';
import 'auth_tokens.dart';

/// Holds the live credentials for the current session (Stage F2 §17).
///
/// - The **access token** lives ONLY in memory (this object's field). It
///   is deliberately lost on process death; the refresh flow rebuilds it
///   on next launch. Never written to disk, a provider snapshot, or a log.
/// - The **refresh token** (and its expiry) is persisted through
///   [SecureStore] only — Keychain / Keystore-backed encrypted store.
///
/// Intentionally not a `StateNotifier`: nothing in the UI should rebuild
/// because a token rotated. `AuthController` owns the user-visible auth
/// *state*; this owns the raw secrets.
class TokenStore {
  TokenStore(this._secure);

  final SecureStore _secure;

  String? _accessToken;
  DateTime? _accessTokenExpiresAt;

  String? get accessToken => _accessToken;

  bool get hasValidAccessToken {
    final exp = _accessTokenExpiresAt;
    if (_accessToken == null || exp == null) return false;
    return DateTime.now().isBefore(exp.subtract(const Duration(seconds: 30)));
  }

  void setAccessToken(String token, DateTime expiresAt) {
    _accessToken = token;
    _accessTokenExpiresAt = expiresAt;
  }

  void clearAccessToken() {
    _accessToken = null;
    _accessTokenExpiresAt = null;
  }

  Future<String?> readRefreshToken() => _secure.readRefreshToken();

  Future<DateTime?> readRefreshExpiry() => _secure.readRefreshExpiry();

  Future<bool> hasRefreshToken() async =>
      (await _secure.readRefreshToken())?.isNotEmpty ?? false;

  /// Persist a freshly issued / rotated credential pair: access token to
  /// memory, refresh token + expiry to secure storage.
  Future<void> persist(AuthTokens tokens) async {
    setAccessToken(tokens.accessToken, tokens.accessTokenExpiresAt);
    if (tokens.refreshToken.isNotEmpty) {
      await _secure.writeRefreshToken(tokens.refreshToken);
      if (tokens.refreshTokenExpiresAt != null) {
        await _secure.writeRefreshExpiry(tokens.refreshTokenExpiresAt!);
      }
    }
  }

  /// Full local sign-out: drop the in-memory access token and wipe the
  /// persisted refresh token + expiry. Does not call the API.
  Future<void> clear() async {
    clearAccessToken();
    await _secure.clear();
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStoreProvider));
});
