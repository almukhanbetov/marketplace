import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret, per-device UI preferences (theme mode, language). Never
/// stores anything sensitive — the refresh token lives in [SecureStore]
/// exclusively.
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeMode = 'nova.pref.theme_mode';
  static const _kLocale = 'nova.pref.locale';

  String? get themeMode => _prefs.getString(_kThemeMode);
  Future<void> setThemeMode(String value) =>
      _prefs.setString(_kThemeMode, value);

  String? get locale => _prefs.getString(_kLocale);
  Future<void> setLocale(String value) => _prefs.setString(_kLocale, value);
}

/// Overridden in `main()` with the resolved instance so the rest of the
/// tree can read it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

final preferencesStoreProvider = Provider<PreferencesStore>((ref) {
  return PreferencesStore(ref.watch(sharedPreferencesProvider));
});
