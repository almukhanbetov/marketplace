import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Compact rating: a star, the number, and an optional review count.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = 13,
    this.showCount = true,
  });

  final double rating;
  final int? reviewCount;
  final double size;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 3, color: c.star),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
        if (showCount && reviewCount != null && reviewCount! > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($reviewCount)',
            style: TextStyle(fontSize: size - 1, color: c.text3),
          ),
        ],
      ],
    );
  }
}
