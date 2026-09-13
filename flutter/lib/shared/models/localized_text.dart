import '../../core/localization/app_strings.dart';

/// A backend localized-text object: `{ "ru": "...", "kk": "...", "en": "..." }`.
///
/// Widgets never switch on locale themselves — they call
/// `strings.pick(model.name)`, which applies the fallback chain
/// (current locale → ru → en → first non-empty) via `AppStrings.localized`.
class LocalizedText {
  const LocalizedText({this.ru = '', this.kk = '', this.en = ''});

  final String ru;
  final String kk;
  final String en;

  static const empty = LocalizedText();

  bool get isEmpty => ru.isEmpty && kk.isEmpty && en.isEmpty;

  /// Raw map form — what `AppStrings.localized` consumes.
  Map<String, dynamic> get map => {'ru': ru, 'kk': kk, 'en': en};

  factory LocalizedText.fromJson(Object? json) {
    if (json is! Map) return empty;
    String s(Object? v) => v is String ? v : '';
    return LocalizedText(
      ru: s(json['ru']),
      kk: s(json['kk']),
      en: s(json['en']),
    );
  }
}

extension LocalizedPick on AppStrings {
  /// Localized value of a backend text object for the current locale.
  String pick(LocalizedText text) => localized(text.map);
}
