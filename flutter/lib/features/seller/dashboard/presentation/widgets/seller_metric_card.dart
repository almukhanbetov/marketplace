import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';

/// One compact metric tile — icon, value, label. Mobile-first: never part
/// of a table (Stage F6A §12). [tone] tints the icon chip; [emphasize]
/// enlarges the value for the headline metric.
class SellerMetricCard extends StatelessWidget {
  const SellerMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.tone = MetricTone.neutral,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final MetricTone tone;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final (fg, bg) = switch (tone) {
      MetricTone.neutral => (c.text2, c.surface2),
      MetricTone.accent => (c.accent, c.accentSoft),
      MetricTone.success => (c.success, c.success.withValues(alpha: 0.13)),
      MetricTone.warning => (c.warning, c.warning.withValues(alpha: 0.15)),
    };

    return Container(
      padding: const EdgeInsets.all(NovaSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(NovaRadii.md),
        border: Border.all(
          color: emphasize ? fg.withValues(alpha: 0.4) : c.border,
        ),
        boxShadow: NovaShadows.card(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(NovaRadii.xs),
            ),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(height: NovaSpace.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: emphasize ? 19 : 16,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: c.text3, height: 1.25),
          ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum MetricTone { neutral, accent, success, warning }
