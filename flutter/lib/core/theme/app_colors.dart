import 'package:flutter/material.dart';

/// NOVA design tokens, ported 1:1 from `frontend/styles/variables.css`.
///
/// Two palettes:
///  - [dark]  — "Dark Premium" (the web default): near-black `#0a0b0d`
///    ground, graphite surfaces, blue accent.
///  - [light] — "Light / Vivid": strictly white `#FFFFFF` ground, deepened
///    coral accent that stays legible as text on white.
@immutable
class NovaColors extends ThemeExtension<NovaColors> {
  const NovaColors({
    required this.bg,
    required this.bgElevated,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.textInverse,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.accent2,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerSoft,
    required this.price,
    required this.priceOld,
    required this.star,
    required this.overlay,
    required this.heroGradient,
    required this.saleGradient,
  });

  final Color bg;
  final Color bgElevated;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color text2;
  final Color text3;
  final Color textInverse;
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color accent2;
  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerSoft;
  final Color price;
  final Color priceOld;
  final Color star;
  final Color overlay;
  final List<Color> heroGradient;
  final List<Color> saleGradient;

  static const dark = NovaColors(
    bg: Color(0xFF0A0B0D),
    bgElevated: Color(0xFF0E1013),
    surface: Color(0xFF15171B),
    surface2: Color(0xFF1C1F24),
    surface3: Color(0xFF24272E),
    border: Color(0xFF2A2D34),
    borderStrong: Color(0xFF383C45),
    text: Color(0xFFF3F4F6),
    text2: Color(0xFF9AA0AC),
    text3: Color(0xFF6B7280),
    textInverse: Color(0xFF0A0B0D),
    accent: Color(0xFF4F8DFF),
    accentHover: Color(0xFF6EA0FF),
    accentSoft: Color(0x244F8DFF),
    accent2: Color(0xFFFFB648),
    success: Color(0xFF35C98F),
    warning: Color(0xFFFFB648),
    danger: Color(0xFFFF5C72),
    dangerSoft: Color(0x24FF5C72),
    price: Color(0xFFF3F4F6),
    priceOld: Color(0xFF6B7280),
    star: Color(0xFFFFB648),
    overlay: Color(0xAE040506),
    heroGradient: [Color(0xFF1A2340), Color(0xFF10131A), Color(0xFF0A0B0D)],
    saleGradient: [Color(0xFFFF5C72), Color(0xFFFF8A48)],
  );

  static const light = NovaColors(
    bg: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF7F7F8),
    surface3: Color(0xFFF3F4F6),
    border: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFD1D5DB),
    text: Color(0xFF111111),
    text2: Color(0xFF6B7280),
    text3: Color(0xFF78808C),
    textInverse: Color(0xFFFFFFFF),
    accent: Color(0xFFDA2C55),
    accentHover: Color(0xFFB81F44),
    accentSoft: Color(0x1ADA2C55),
    accent2: Color(0xFFC2410C),
    success: Color(0xFF0B7A5A),
    warning: Color(0xFFB45309),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0x1ADC2626),
    price: Color(0xFF111111),
    priceOld: Color(0xFF9CA3AF),
    star: Color(0xFFC9930B),
    overlay: Color(0x800F0F0F),
    heroGradient: [Color(0xFF4A1C5C), Color(0xFFBA2F5C), Color(0xFFFF7A3D)],
    saleGradient: [Color(0xFFFF2E5A), Color(0xFFFF9433)],
  );

  @override
  NovaColors copyWith({
    Color? bg,
    Color? bgElevated,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? text2,
    Color? text3,
    Color? textInverse,
    Color? accent,
    Color? accentHover,
    Color? accentSoft,
    Color? accent2,
    Color? success,
    Color? warning,
    Color? danger,
    Color? dangerSoft,
    Color? price,
    Color? priceOld,
    Color? star,
    Color? overlay,
    List<Color>? heroGradient,
    List<Color>? saleGradient,
  }) {
    return NovaColors(
      bg: bg ?? this.bg,
      bgElevated: bgElevated ?? this.bgElevated,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      textInverse: textInverse ?? this.textInverse,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSoft: accentSoft ?? this.accentSoft,
      accent2: accent2 ?? this.accent2,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      price: price ?? this.price,
      priceOld: priceOld ?? this.priceOld,
      star: star ?? this.star,
      overlay: overlay ?? this.overlay,
      heroGradient: heroGradient ?? this.heroGradient,
      saleGradient: saleGradient ?? this.saleGradient,
    );
  }

  @override
  NovaColors lerp(covariant NovaColors? other, double t) {
    if (other == null) return this;
    return NovaColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accent2: Color.lerp(accent2, other.accent2, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      price: Color.lerp(price, other.price, t)!,
      priceOld: Color.lerp(priceOld, other.priceOld, t)!,
      star: Color.lerp(star, other.star, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      heroGradient: t < 0.5 ? heroGradient : other.heroGradient,
      saleGradient: t < 0.5 ? saleGradient : other.saleGradient,
    );
  }
}

/// `context.nova` → the active [NovaColors] palette.
extension NovaColorsX on BuildContext {
  NovaColors get nova =>
      Theme.of(this).extension<NovaColors>() ?? NovaColors.dark;
}
