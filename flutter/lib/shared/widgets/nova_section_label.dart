import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';

/// The small uppercase "eyebrow" that labels a group of rows — account
/// details, checkout sections, dashboard quick-actions, finance breakdown.
/// Was copy-pasted as `bodySmall.copyWith(letterSpacing: .6, w700)` in
/// four screens; now one widget so they line up (§6/§52).
class NovaSectionLabel extends StatelessWidget {
  const NovaSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      NovaSpace.md,
      NovaSpace.md,
      NovaSpace.md,
      NovaSpace.xs,
    ),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
