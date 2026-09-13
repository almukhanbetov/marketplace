import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/core/theme/app_colors.dart';
import 'package:nova_marketplace/core/theme/app_theme.dart';

void main() {
  test('Light theme background is strictly #FFFFFF (Stage F1 §52)', () {
    final light = AppTheme.light();
    expect(light.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(light.extension<NovaColors>()!.bg, const Color(0xFFFFFFFF));
    expect(light.extension<NovaColors>()!.surface, const Color(0xFFFFFFFF));
  });

  test('Dark theme is near-black graphite (Stage F1 §53)', () {
    final dark = AppTheme.dark();
    expect(dark.scaffoldBackgroundColor, const Color(0xFF0A0B0D));
    expect(dark.brightness, Brightness.dark);
  });

  test('both themes register the NovaColors extension', () {
    expect(AppTheme.light().extension<NovaColors>(), isNotNull);
    expect(AppTheme.dark().extension<NovaColors>(), isNotNull);
  });

  test('accent colours match the NOVA tokens', () {
    expect(
      AppTheme.dark().extension<NovaColors>()!.accent,
      const Color(0xFF4F8DFF),
    );
    expect(
      AppTheme.light().extension<NovaColors>()!.accent,
      const Color(0xFFDA2C55),
    );
  });
}
