/// Every persistent storage key in one place — never a string literal at
/// a call site.
class StorageKeys {
  const StorageKeys._();

  // --- Secure (flutter_secure_storage / Keychain) — SENSITIVE ---
  static const refreshToken = 'nova_refresh_token';
  static const refreshExpiresAt = 'nova_refresh_expires_at';

  // --- Preferences (shared_preferences) — NOT sensitive ---
  static const themeMode = 'nova.pref.theme_mode';
  static const locale = 'nova.pref.locale';
}
