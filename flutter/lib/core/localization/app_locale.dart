import 'package:flutter/widgets.dart';

/// The three languages NOVA supports everywhere — Russian, Kazakh,
/// English. Matches the backend's `LocalizedText { ru, kk, en }` and the
/// web `mp_lang` values (`ru` | `kk` | `en`).
enum AppLocale {
  ru('ru', 'Русский'),
  kk('kk', 'Қазақша'),
  en('en', 'English');

  const AppLocale(this.code, this.label);

  /// ISO code — also the key used in the backend's localized-text objects.
  final String code;
  final String label;

  Locale get flutterLocale => Locale(code);

  static AppLocale fromCode(String? code) => switch (code) {
    'kk' => AppLocale.kk,
    'en' => AppLocale.en,
    _ => AppLocale.ru,
  };

  static const fallback = AppLocale.ru;
}
