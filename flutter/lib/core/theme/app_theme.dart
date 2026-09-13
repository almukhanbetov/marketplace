import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Builds the two [ThemeData]s from [NovaColors] and the [NovaSpace] /
/// [NovaRadii] / [NovaDurations] tokens. Motion stays in the 150–300ms
/// band the web uses; radii come from [NovaRadii] so every control on
/// screen shares the same four corner sizes (§8).
class AppTheme {
  const AppTheme._();

  static const _radiusSm = NovaRadii.sm; // 10 — inputs, buttons
  static const _radiusMd = NovaRadii.md; // 14 — cards
  static const _radiusLg = NovaRadii.lg; // 18 — sheets

  static const _fontFallback = <String>[
    '-apple-system',
    'Roboto',
    'Segoe UI',
    'Helvetica Neue',
    'Arial',
  ];

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData dark() => _build(Brightness.dark, NovaColors.dark);
  static ThemeData light() => _build(Brightness.light, NovaColors.light);

  static ThemeData _build(Brightness brightness, NovaColors c) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: isDark ? c.textInverse : Colors.white,
      secondary: c.accent2,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: c.surface3,
      outline: c.border,
    );

    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.border,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: _pageTransitions,
      visualDensity: VisualDensity.standard,
      extensions: [c],
      textTheme: _textTheme(base.textTheme, c),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: isDark ? Colors.black : const Color(0x14101828),
        centerTitle: false,
        titleSpacing: NovaSpace.md,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          fontFamilyFallback: _fontFallback,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentSoft,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: NovaRadii.borderPill,
        ),
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.accent : c.text2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.accent : c.text2, size: 24);
        }),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(_radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLg),
        ),
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: c.text2, fontSize: 14, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        hintStyle: TextStyle(color: c.text3),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NovaSpace.md,
          vertical: NovaSpace.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        errorStyle: TextStyle(color: c.danger, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
          minimumSize: const Size.fromHeight(48),
          animationDuration: NovaDurations.fast,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size.fromHeight(48),
          animationDuration: NovaDurations.fast,
          side: BorderSide(color: c.borderStrong),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.text2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface3,
        contentTextStyle: TextStyle(
          color: c.text,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(NovaSpace.sm),
        elevation: isDark ? 0 : 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgElevated,
        modalBackgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.overlay,
        shape: const RoundedRectangleBorder(borderRadius: NovaRadii.sheetTop),
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface2,
        selectedColor: c.accentSoft,
        checkmarkColor: c.accent,
        side: BorderSide(color: c.border),
        labelStyle: TextStyle(color: c.text2, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: c.accent, fontSize: 13),
        padding: const EdgeInsets.symmetric(
          horizontal: NovaSpace.sm,
          vertical: NovaSpace.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: NovaRadii.borderPill),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.text2,
        textColor: c.text,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surface3,
          borderRadius: BorderRadius.circular(NovaRadii.xs),
        ),
        textStyle: TextStyle(color: c.text, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        circularTrackColor: Colors.transparent,
      ),
    );
  }

  /// The typographic hierarchy (§6). One place owns every text size:
  ///
  /// | slot          | use                         | size / weight |
  /// |---------------|-----------------------------|---------------|
  /// | displaySmall  | splash / hero wordmark      | 28 / 800      |
  /// | headlineMedium| page hero (auth title)      | 24 / 800      |
  /// | headlineSmall | page title                  | 20 / 700      |
  /// | titleLarge    | section title               | 17 / 700      |
  /// | titleMedium   | card title                  | 15 / 600      |
  /// | titleSmall    | dense card title / label    | 13.5 / 700    |
  /// | bodyLarge     | body copy                   | 15 / 400      |
  /// | bodyMedium    | secondary body              | 14 / 400      |
  /// | bodySmall     | metadata                    | 12 / 400      |
  /// | labelLarge    | button / strong inline      | 14 / 600      |
  /// | labelSmall    | caption / eyebrow (uppercase)| 11 / 700     |
  static TextTheme _textTheme(TextTheme base, NovaColors c) {
    TextStyle st(
      double size,
      FontWeight w, {
      Color? color,
      double? height,
      double? spacing,
    }) => TextStyle(
      fontSize: size,
      fontWeight: w,
      color: color ?? c.text,
      height: height,
      letterSpacing: spacing,
      fontFamilyFallback: _fontFallback,
    );
    return base.copyWith(
      displaySmall: st(28, FontWeight.w800, spacing: -0.5),
      headlineMedium: st(24, FontWeight.w800, spacing: -0.4),
      headlineSmall: st(20, FontWeight.w700, spacing: -0.3),
      titleLarge: st(17, FontWeight.w700, spacing: -0.2),
      titleMedium: st(15, FontWeight.w600),
      titleSmall: st(13.5, FontWeight.w700),
      bodyLarge: st(15, FontWeight.w400, height: 1.4),
      bodyMedium: st(14, FontWeight.w400, height: 1.4, color: c.text2),
      bodySmall: st(12, FontWeight.w400, color: c.text3),
      labelLarge: st(14, FontWeight.w600),
      labelMedium: st(12.5, FontWeight.w600, color: c.text2),
      labelSmall: st(11, FontWeight.w700, color: c.text3, spacing: 0.6),
    );
  }
}
