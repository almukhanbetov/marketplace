import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// `-18%` sale badge.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent, this.compact = false});

  final int percent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (percent <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: context.nova.danger,
        borderRadius: BorderRadius.circular(NovaRadii.xs),
      ),
      child: Text(
        '-$percent%',
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 10.5 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// "✓ Verified" pill for a seller.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, size: 14, color: c.accent),
        if (label != null) ...[
          const SizedBox(width: 3),
          Text(
            label!,
            style: TextStyle(
              fontSize: 11.5,
              color: c.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
