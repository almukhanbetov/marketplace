import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';

/// Current price + optional struck-through old price. `price` / `oldPrice`
/// are the backend's exact decimal strings.
class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.price,
    this.oldPrice,
    this.priceSize = 16,
    this.oldSize = 12.5,
    this.wrap = true,
  });

  final String price;
  final String? oldPrice;
  final double priceSize;
  final double oldSize;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final showOld = oldPrice != null && oldPrice != price;

    final current = Text(
      Money.format(price),
      style: TextStyle(
        fontSize: priceSize,
        fontWeight: FontWeight.w800,
        color: c.price,
      ),
    );
    if (!showOld) return current;

    final old = Text(
      Money.format(oldPrice),
      style: TextStyle(
        fontSize: oldSize,
        color: c.priceOld,
        decoration: TextDecoration.lineThrough,
      ),
    );

    return wrap
        ? Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [current, old],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              current,
              const SizedBox(width: 6),
              Flexible(child: old),
            ],
          );
  }
}
