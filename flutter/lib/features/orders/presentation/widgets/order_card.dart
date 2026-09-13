import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/nova_network_image.dart';
import '../../data/order_models.dart';
import 'order_status_badge.dart';

/// One row of the orders list — number, date, status, a strip of item
/// thumbnails, item count and total. Tap → order detail (§36).
class OrderCard extends ConsumerWidget {
  const OrderCard({super.key, required this.order, required this.onTap});

  final OrderListItemModel order;
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
                Text(
                  Dates.short(order.createdAt),
                  style: TextStyle(fontSize: 12, color: c.text3),
                ),
                const SizedBox(height: 12),
                _Thumbs(previews: order.itemsPreview),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      s(
                        'orders.itemsCount',
                      ).replaceFirst('{n}', '${order.itemCount}'),
                      style: TextStyle(fontSize: 12.5, color: c.text2),
                    ),
                    const Spacer(),
                    Text(
                      Money.format(order.total),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.price,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.previews});
  final List<OrderItemPreviewModel> previews;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    const max = 4;
    final shown = previews.take(max).toList();
    final extra = previews.length - shown.length;

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          for (final p in shown)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 44,
                height: 44,
                child: NovaNetworkImage(
                  url: p.primaryImage,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          if (extra > 0)
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+$extra',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.text2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
