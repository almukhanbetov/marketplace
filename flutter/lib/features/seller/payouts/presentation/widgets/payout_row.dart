import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/utils/dates.dart';
import '../../../../../core/utils/money.dart';
import '../../data/seller_payout_models.dart';

/// One payout: amount, status, requested date, processed date (Stage F6D §6).
class PayoutRow extends ConsumerWidget {
  const PayoutRow({super.key, required this.payout});

  final SellerPayoutModel payout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Container(
      margin: const EdgeInsets.only(bottom: NovaSpace.sm),
      padding: const EdgeInsets.all(NovaSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(NovaRadii.md),
        border: Border.all(color: c.border),
        boxShadow: NovaShadows.card(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Money.format(payout.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: payout.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s(
              'payout.requestedOn',
            ).replaceFirst('{date}', Dates.short(payout.requestedAt)),
            style: TextStyle(fontSize: 12, color: c.text3),
          ),
          if (payout.processedAt != null)
            Text(
              s(
                'payout.processedOn',
              ).replaceFirst('{date}', Dates.short(payout.processedAt!)),
              style: TextStyle(fontSize: 12, color: c.text3),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends ConsumerWidget {
  const _StatusBadge({required this.status});
  final PayoutStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final (fg, bg) = switch (status) {
      PayoutStatus.paid => (c.success, c.success.withValues(alpha: 0.13)),
      PayoutStatus.processing => (c.warning, c.warning.withValues(alpha: 0.15)),
      PayoutStatus.pending => (c.accent, c.accentSoft),
      PayoutStatus.rejected => (c.danger, c.dangerSoft),
      PayoutStatus.unknown => (c.text2, c.surface2),
    };
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
}
