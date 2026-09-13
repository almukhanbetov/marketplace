import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_keys.dart';

/// Thin wrapper over [FlutterSecureStorage] (Keychain on iOS,
/// AES-GCM-encrypted store keyed by the Android Keystore on Android). This
/// is the ONLY place the app is allowed to persist the refresh token —
/// never `SharedPreferences`, never a plain file, never in a provider
/// that gets logged (Stage F2 §15/§16).
///
/// Non-secret per-device preferences (theme, locale) use a separate
/// lightweight store — see `PreferencesStore`.
abstract interface class SecureStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> deleteRefreshToken();

  Future<DateTime?> readRefreshExpiry();
  Future<void> writeRefreshExpiry(DateTime expiresAt);

  /// Wipes every secure key this app owns — logout / unrecoverable auth
  /// failure.
  Future<void> clear();
}

class SecureStoreImpl implements SecureStore {
  SecureStoreImpl(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);

  @override
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: StorageKeys.refreshToken, value: token);

  @override
  Future<void> deleteRefreshToken() =>
      _storage.delete(key: StorageKeys.refreshToken);

  @override
  Future<DateTime?> readRefreshExpiry() async {
    final raw = await _storage.read(key: StorageKeys.refreshExpiresAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> writeRefreshExpiry(DateTime expiresAt) => _storage.write(
    key: StorageKeys.refreshExpiresAt,
    value: expiresAt.toUtc().toIso8601String(),
  );

  @override
  Future<void> clear() async {
    await _storage.delete(key: StorageKeys.refreshToken);
    await _storage.delete(key: StorageKeys.refreshExpiresAt);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // Android: v11 always uses strong AES-GCM + Keystore-wrapped key — the
  // encrypted blob is worthless off-device even if a backup captured it,
  // and the manifest additionally excludes it from auto-backup.
  // iOS: readable only after the first unlock following a boot (enough for
  // a background session refresh; no shared keychain group).
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStoreImpl(ref.watch(secureStorageProvider));
});
