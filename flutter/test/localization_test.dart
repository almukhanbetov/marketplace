import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/localization/app_locale.dart';
import 'package:nova_marketplace/core/localization/app_strings.dart';
import 'package:nova_marketplace/core/localization/strings/strings_en.dart';
import 'package:nova_marketplace/core/localization/strings/strings_kk.dart';
import 'package:nova_marketplace/core/localization/strings/strings_ru.dart';

void main() {
  group('translation coverage', () {
    test('KK and EN cover exactly the RU key set — no missing, no extras', () {
      final ruKeys = kStringsRu.keys.toSet();
      expect(
        kStringsKk.keys.toSet(),
        equals(ruKeys),
        reason: 'Kazakh key mismatch',
      );
      expect(
        kStringsEn.keys.toSet(),
        equals(ruKeys),
        reason: 'English key mismatch',
      );
    });

    test('no value is left blank in any language', () {
      for (final map in [kStringsRu, kStringsKk, kStringsEn]) {
        for (final entry in map.entries) {
          expect(
            entry.value.trim(),
            isNotEmpty,
            reason: 'empty value for ${entry.key}',
          );
        }
      }
    });

    test('Kazakh is genuinely translated, not copied from Russian', () {
      // A handful of nav labels that must differ between RU and KK.
      for (final key in [
        'nav.home',
        'nav.favorites',
        'nav.cart',
        'action.login',
      ]) {
        expect(kStringsKk[key], isNot(equals(kStringsRu[key])), reason: key);
      }
    });
  });

  group('AppStrings', () {
    test('resolves per-locale values', () {
      expect(AppStrings(AppLocale.ru)('nav.home'), 'Главная');
      expect(AppStrings(AppLocale.kk)('nav.home'), 'Басты бет');
      expect(AppStrings(AppLocale.en)('nav.home'), 'Home');
    });

    test('localized() follows the locale → ru → en → first fallback chain', () {
      final en = AppStrings(AppLocale.en);
      expect(
        en.localized({'ru': 'Телефон', 'kk': 'Телефон', 'en': 'Phone'}),
        'Phone',
      );
      // Missing EN → falls back to RU.
      expect(
        en.localized({'ru': 'Только РУ', 'kk': '', 'en': ''}),
        'Только РУ',
      );
      expect(en.localized(null), '');
    });

    test('apiError maps known codes and falls back for unknown ones', () {
      final ru = AppStrings(AppLocale.ru);
      expect(ru.apiError('INVALID_CREDENTIALS'), contains('пароль'));
      expect(ru.apiError('SOME_NEW_CODE'), equals(ru('error.UNKNOWN_ERROR')));
    });
  });
}
