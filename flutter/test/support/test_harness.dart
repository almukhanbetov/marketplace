import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova_marketplace/core/auth/auth_repository.dart';
import 'package:nova_marketplace/core/auth/auth_repository_impl.dart';
import 'package:nova_marketplace/core/storage/preferences_store.dart';
import 'package:nova_marketplace/core/storage/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [SecureStore] so tests never touch the platform Keychain
/// channel (unavailable in the unit-test VM). Seed [refreshToken] /
/// [refreshExpiry] to simulate a returning user.
class FakeSecureStore implements SecureStore {
  FakeSecureStore({String? refreshToken, DateTime? refreshExpiry})
    : _token = refreshToken,
      _expiry = refreshExpiry;

  String? _token;
  DateTime? _expiry;

  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> writeRefreshToken(String token) async {
    writeCount++;
    _token = token;
  }

  @override
  Future<void> deleteRefreshToken() async => _token = null;

  @override
  Future<DateTime?> readRefreshExpiry() async => _expiry;

  @override
  Future<void> writeRefreshExpiry(DateTime expiresAt) async =>
      _expiry = expiresAt;

  @override
  Future<void> clear() async {
    clearCount++;
    _token = null;
    _expiry = null;
  }
}

Future<SharedPreferences> _mockPrefs(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  return SharedPreferences.getInstance();
}

/// A [ProviderContainer] for unit tests, wired with mock storage. The
/// caller is responsible for `addTearDown(container.dispose)`.
Future<ProviderContainer> makeTestContainer({
  Map<String, Object> prefs = const {},
  FakeSecureStore? secureStore,
  AuthRepository? authRepo,
}) async {
  final sp = await _mockPrefs(prefs);
  return ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      secureStoreProvider.overrideWithValue(secureStore ?? FakeSecureStore()),
      if (authRepo != null) authRepositoryProvider.overrideWithValue(authRepo),
    ],
  );
}

/// Wraps [child] in a test [ProviderScope] with mock storage.
Future<Widget> wrapForTest(
  Widget child, {
  Map<String, Object> prefs = const {},
  FakeSecureStore? secureStore,
  AuthRepository? authRepo,
}) async {
  final sp = await _mockPrefs(prefs);
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      secureStoreProvider.overrideWithValue(secureStore ?? FakeSecureStore()),
      if (authRepo != null) authRepositoryProvider.overrideWithValue(authRepo),
    ],
    child: child,
  );
}
