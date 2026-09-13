import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/order_models.dart';

/// Small pill for an order or payment state — colour-coded, localized,
/// with a semantics label so it's announced (§69).
class OrderStatusBadge extends ConsumerWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final (fg, bg) = _colors(c);
    final label = s(status.labelKey);

    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }

  (Color, Color) _colors(NovaColors c) {
    switch (status) {
      case OrderStatus.paid:
      case OrderStatus.confirmed:
        return (c.success, c.success.withValues(alpha: 0.13));
      case OrderStatus.delivered:
        return (c.accent, c.accentSoft);
      case OrderStatus.shipped:
      case OrderStatus.processing:
        return (c.warning, c.warning.withValues(alpha: 0.15));
      case OrderStatus.cancelled:
      case OrderStatus.returned:
        return (c.danger, c.dangerSoft);
      case OrderStatus.newOrder:
      case OrderStatus.unknown:
        return (c.text2, c.surface2);
    }
  }
}

class PaymentStatusChip extends ConsumerWidget {
  const PaymentStatusChip({super.key, required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final color = switch (status) {
      PaymentStatus.paid => c.success,
      PaymentStatus.pending => c.warning,
      PaymentStatus.failed => c.danger,
      PaymentStatus.unknown => c.text3,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status == PaymentStatus.paid
              ? Icons.check_circle_rounded
              : Icons.schedule_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          s(status.labelKey),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
