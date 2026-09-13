import 'package:flutter/widgets.dart';

/// NOVA layout tokens (Stage F7A). One vocabulary for spacing, radii,
/// motion and elevation so every screen breathes on the same rhythm
/// instead of each widget inventing its own `SizedBox(height: 13.5)`.
///
/// The scale is deliberately short — 4 / 8 / 12 / 16 / 20 / 24 / 32 —
/// mirroring the web's `--space-*` steps. Anything outside it is a smell.
abstract final class NovaSpace {
  /// 4 — hairline gap between tightly-coupled elements (icon ↔ label).
  static const xxs = 4.0;

  /// 8 — default gap inside a component.
  static const xs = 8.0;

  /// 12 — gap between related rows / compact card padding.
  static const sm = 12.0;

  /// 16 — the page gutter and the standard block gap.
  static const md = 16.0;

  /// 20 — gap between distinct content blocks.
  static const lg = 20.0;

  /// 24 — section separation.
  static const xl = 24.0;

  /// 32 — top-of-screen / empty-state breathing room.
  static const xxl = 32.0;

  /// The horizontal page gutter. Every screen keeps at least this much
  /// clear on both sides (§43/§44).
  static const gutter = md;

  static const pagePadding = EdgeInsets.symmetric(horizontal: gutter);
}

/// Corner radii — matches `--radius-*` on the web. Four steps only.
abstract final class NovaRadii {
  /// 8 — chips, small controls, thumbnails.
  static const xs = 8.0;

  /// 10 — inputs, buttons.
  static const sm = 10.0;

  /// 14 — cards, sheets' inner elements.
  static const md = 14.0;

  /// 18 — bottom sheets, hero surfaces, prominent cards.
  static const lg = 18.0;

  /// Fully round (pills, avatars).
  static const pill = 999.0;

  static const borderXs = BorderRadius.all(Radius.circular(xs));
  static const borderSm = BorderRadius.all(Radius.circular(sm));
  static const borderMd = BorderRadius.all(Radius.circular(md));
  static const borderLg = BorderRadius.all(Radius.circular(lg));
  static const borderPill = BorderRadius.all(Radius.circular(pill));

  /// Top-only large radius for bottom sheets.
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(lg));
}

/// Motion durations — all inside the 150–300ms band the spec asks for
/// (§39). `fast` for state flips, `base` for content, `slow` for the
/// largest transitions.
abstract final class NovaDurations {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);

  static const curve = Curves.easeOutCubic;
  static const curveEmphasized = Curves.easeOutBack;
}

/// Elevation — NOVA leans on borders and surface contrast, not big
/// drop shadows (§9). Light mode gets one whisper-soft shadow to lift
/// cards off `#FFFFFF`; dark mode returns an empty list and relies on
/// the surface step instead.
abstract final class NovaShadows {
  static List<BoxShadow> card(Brightness brightness) =>
      brightness == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0D0B1220),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ];

  /// Slightly stronger — for sticky bars / sheets that sit above content.
  static List<BoxShadow> overlay(Brightness brightness) =>
      brightness == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x14101828),
            blurRadius: 16,
            offset: Offset(0, -3),
          ),
        ];
}

/// A vertical or horizontal gap sized from the [NovaSpace] scale. Cheaper
/// to read than a bare `SizedBox(height: 16)` and impossible to get half
/// a pixel wrong.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key}) : _horizontal = false;
  const Gap.h(this.size, {super.key}) : _horizontal = true;

  final double size;
  final bool _horizontal;

  static const xxs = Gap(NovaSpace.xxs);
  static const xs = Gap(NovaSpace.xs);
  static const sm = Gap(NovaSpace.sm);
  static const md = Gap(NovaSpace.md);
  static const lg = Gap(NovaSpace.lg);
  static const xl = Gap(NovaSpace.xl);

  @override
  Widget build(BuildContext context) =>
      _horizontal ? SizedBox(width: size) : SizedBox(height: size);
}
