import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_locale.dart';
import 'locale_controller.dart';
import 'strings/strings_en.dart';
import 'strings/strings_kk.dart';
import 'strings/strings_ru.dart';

/// The single translation helper. No screen ever writes `if (lang == ...)`
/// — it calls `s('some.key')` or `s.localized(backendTextMap)`.
class AppStrings {
  AppStrings(this.locale)
    : _map = switch (locale) {
        AppLocale.ru => kStringsRu,
        AppLocale.kk => kStringsKk,
        AppLocale.en => kStringsEn,
      } {
    assert(_debugAssertParity());
  }

  final AppLocale locale;
  final Map<String, String> _map;

  /// `s('nav.home')`. Returns the RU value, then the key itself, if a
  /// translation is somehow missing (should never happen — see the assert).
  String call(String key) => _map[key] ?? kStringsRu[key] ?? key;

  /// Picks the right field out of a backend localized-text object
  /// (`{ "ru": "...", "kk": "...", "en": "..." }`) with a sensible
  /// fallback chain: current locale → ru → en → first non-empty.
  String localized(Map<String, dynamic>? text) {
    if (text == null) return '';
    final ordered = [locale.code, 'ru', 'en'];
    for (final code in ordered) {
      final v = text[code];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return text.values.whereType<String>().firstWhere(
      (v) => v.trim().isNotEmpty,
      orElse: () => '',
    );
  }

  /// Maps an API error code to friendly copy, falling back to a generic
  /// message so raw codes never reach the user.
  String apiError(String code) =>
      _map['error.$code'] ?? call('error.UNKNOWN_ERROR');

  bool _debugAssertParity() {
    for (final other in [kStringsKk, kStringsEn]) {
      final missing = kStringsRu.keys.where((k) => !other.containsKey(k));
      final extra = other.keys.where((k) => !kStringsRu.containsKey(k));
      if (missing.isNotEmpty || extra.isNotEmpty) {
        debugPrint(
          'AppStrings parity error — missing: $missing, extra: $extra',
        );
        return false;
      }
    }
    return true;
  }
}

final appStringsProvider = Provider<AppStrings>((ref) {
  return AppStrings(ref.watch(localeControllerProvider));
});
