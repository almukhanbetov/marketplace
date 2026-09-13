import 'auth_requests.dart';
import 'auth_tokens.dart';
import 'auth_user.dart';

/// A completed sign-in: the credential pair plus the user it belongs to.
/// Mobile login/register return both in one round-trip (Stage F2 §10), so
/// the app never needs a follow-up `/auth/me` right after authenticating.
class AuthSession {
  const AuthSession({required this.tokens, required this.user});
  final AuthTokens tokens;
  final AuthUser user;
}

/// Everything the app can ask the backend to do with a session. Concrete
/// implementation: `AuthRepositoryImpl` (Stage F2). Endpoint mapping in
/// `docs/API_MAP.md`.
///
/// The native transport marker (`X-Client: nova-mobile`) is added centrally
/// by `ApiClient` — this layer never sets it per call.
abstract interface class AuthRepository {
  /// `POST /auth/register` — creates a `customer` account (role is never
  /// client-selectable) and returns a ready session.
  Future<AuthSession> register(RegisterRequest request);

  /// `POST /auth/login` — `identifier` is an email or phone.
  Future<AuthSession> login(LoginRequest request);

  /// `GET /auth/me` — the current user, using the in-memory access token.
  Future<AuthUser> me();

  /// `POST /auth/refresh` using the persisted refresh token. Rotates it
  /// (old token dies, new one is persisted) and returns the new pair.
  ///
  /// Returns `null` when the session is **definitively** gone (expired /
  /// revoked / reused) — local credentials are cleared in that case.
  /// **Throws** `ApiException` for a transient failure (offline, timeout,
  /// 5xx) — the refresh token is kept so a later attempt can still
  /// restore the session (Stage F2 §31).
  Future<AuthTokens?> refresh();

  /// `POST /auth/logout` — revokes the current session server-side (best
  /// effort) and always clears local credentials, even offline.
  Future<void> logout();

  /// `POST /auth/logout-all` — revokes every session for the user.
  Future<void> logoutAll();
}
