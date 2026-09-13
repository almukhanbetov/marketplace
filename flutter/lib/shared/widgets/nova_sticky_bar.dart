import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// The bottom-docked action bar shared by product detail, cart and
/// checkout (§17/§20/§22). One widget so all three get the same elevated
/// surface, hairline top border, soft lift shadow and — critically — the
/// same `SafeArea(top: false)` so the CTA never sits under the gesture
/// bar (§44).
class NovaStickyBar extends StatelessWidget {
  const NovaStickyBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      NovaSpace.md,
      NovaSpace.sm,
      NovaSpace.md,
      NovaSpace.sm,
    ),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bgElevated,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: NovaShadows.overlay(Theme.of(context).brightness),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
