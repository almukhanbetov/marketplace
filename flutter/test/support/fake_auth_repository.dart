import 'package:nova_marketplace/core/auth/auth_repository.dart';
import 'package:nova_marketplace/core/auth/auth_requests.dart';
import 'package:nova_marketplace/core/auth/auth_tokens.dart';
import 'package:nova_marketplace/core/auth/auth_user.dart';
import 'package:nova_marketplace/core/errors/api_exception.dart';

AuthTokens fakeTokens({
  String access = 'access-1',
  String refresh = 'refresh-1',
}) => AuthTokens(
  accessToken: access,
  accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
  refreshToken: refresh,
  refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
);

AuthUser fakeUser({
  int id = 1,
  String role = 'customer',
  int? sellerId,
  String name = 'Test User',
  String email = 'test@example.com',
}) => AuthUser(
  id: id,
  fullName: name,
  role: role,
  isActive: true,
  email: email,
  sellerId: sellerId,
);

/// Scriptable [AuthRepository] for controller / router tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.onLogin,
    this.onRegister,
    this.onRefresh,
    this.onMe,
    this.onLogout,
  });

  Future<AuthSession> Function(LoginRequest)? onLogin;
  Future<AuthSession> Function(RegisterRequest)? onRegister;
  Future<AuthTokens?> Function()? onRefresh;
  Future<AuthUser> Function()? onMe;
  Future<void> Function()? onLogout;

  int loginCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;
  int logoutAllCalls = 0;

  @override
  Future<AuthSession> login(LoginRequest request) {
    loginCalls++;
    return (onLogin ??
        (_) async =>
            AuthSession(tokens: fakeTokens(), user: fakeUser()))(request);
  }

  @override
  Future<AuthSession> register(RegisterRequest request) {
    return (onRegister ??
        (_) async =>
            AuthSession(tokens: fakeTokens(), user: fakeUser()))(request);
  }

  @override
  Future<AuthTokens?> refresh() {
    refreshCalls++;
    return (onRefresh ?? () async => null)();
  }

  @override
  Future<AuthUser> me() => (onMe ?? () async => fakeUser())();

  @override
  Future<void> logout() {
    logoutCalls++;
    return (onLogout ?? () async {})();
  }

  @override
  Future<void> logoutAll() async {
    logoutAllCalls++;
  }
}

ApiException unauthorized() => ApiException(
  kind: ApiErrorKind.unauthorized,
  code: 'SESSION_EXPIRED',
  message: 'expired',
  statusCode: 401,
);

ApiException offline() => ApiException(
  kind: ApiErrorKind.network,
  code: ApiException.codeNetwork,
  message: 'offline',
);
