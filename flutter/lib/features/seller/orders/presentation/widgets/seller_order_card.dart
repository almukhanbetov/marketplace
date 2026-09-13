import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/utils/dates.dart';
import '../../../../../core/utils/money.dart';
import '../../../../orders/presentation/widgets/order_status_badge.dart';
import '../../data/seller_order_models.dart';

/// One seller order as a mobile card (Stage F6C §3) — number, date, status,
/// this seller's item count, and this seller's gross / commission / net.
/// Read-only: tapping opens the (also read-only) detail.
class SellerOrderCard extends ConsumerWidget {
  const SellerOrderCard({super.key, required this.order, required this.onTap});

  final SellerOrderListItem order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Semantics(
      button: true,
      label: '${order.orderNumber}, ${s(order.status.labelKey)}',
      child: Container(
        margin: const EdgeInsets.only(bottom: NovaSpace.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(NovaRadii.md),
          border: Border.all(color: c.border),
          boxShadow: NovaShadows.card(Theme.of(context).brightness),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(NovaSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OrderStatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      Dates.short(order.createdAt),
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s(
                        'seller.orders.itemsN',
                      ).replaceFirst('{n}', '${order.sellerItemCount}'),
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AmountRow(
                  label: s('seller.orders.gross'),
                  value: Money.format(order.sellerGrossAmount),
                ),
                _AmountRow(
                  label: s('seller.orders.commission'),
                  value: '−${Money.format(order.sellerCommissionAmount)}',
                  tone: c.text3,
                ),
                const SizedBox(height: 2),
                _AmountRow(
                  label: s('seller.orders.net'),
                  value: Money.format(order.sellerNetAmount),
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.tone,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? tone;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: emphasize ? 13 : 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
                color: emphasize ? c.text : (tone ?? c.text2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 15 : 12.5,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? c.price : (tone ?? c.text),
            ),
          ),
        ],
      ),
    );
  }
}
