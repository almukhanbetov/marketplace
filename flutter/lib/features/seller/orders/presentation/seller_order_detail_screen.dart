import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nova_skeleton.dart';
import '../../../orders/presentation/widgets/order_status_badge.dart';
import '../application/seller_orders_controller.dart';
import '../data/seller_order_models.dart';

/// `GET /seller/orders/:id` — read-only, seller-scoped. Only THIS seller's
/// lines and amounts appear; the backend returns `ORDER_NOT_FOUND` for an
/// order with no line of this seller (Stage F6C §4/§5). Every value is a
/// historical snapshot from the order response, never today's catalog
/// (§8). There is deliberately no status-changing control on this screen
/// (§16).
class SellerOrderDetailScreen extends ConsumerWidget {
  const SellerOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final id = int.tryParse(orderId);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.orders.detailTitle'))),
      body: id == null
          ? ErrorView(message: s('error.INVALID_ORDER_ID'))
          : ref
                .watch(sellerOrderDetailProvider(id))
                .when(
                  loading: () => const _DetailSkeleton(),
                  error: (e, _) => ErrorView(
                    error: e,
                    onRetry: () =>
                        ref.invalidate(sellerOrderDetailProvider(id)),
                  ),
                  data: (order) => RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(sellerOrderDetailProvider(id)),
                    child: _Body(order: order),
                  ),
                ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});
  final SellerOrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.orderNumber,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ),
            OrderStatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          s(
            'order.detail.placedOn',
          ).replaceFirst('{date}', Dates.shortWithTime(order.createdAt)),
          style: TextStyle(fontSize: 12.5, color: c.text3),
        ),
        const SizedBox(height: 4),
        Text(
          s('seller.orders.yourLinesOnly'),
          style: TextStyle(fontSize: 11.5, color: c.text3),
        ),
        const SizedBox(height: 20),

        _SectionTitle(s('seller.orders.items')),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            children: [
              for (var i = 0; i < order.items.length; i++) ...[
                if (i > 0) Divider(height: 18, color: c.border),
                _ItemRow(item: order.items[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        _SectionTitle(s('seller.orders.delivery')),
        const SizedBox(height: 8),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((order.delivery.title ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    order.delivery.title!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Text(
                '${order.delivery.city}, ${order.delivery.oneLine}',
                style: TextStyle(color: c.text2, height: 1.35),
              ),
              if ((order.delivery.postalCode ?? '').isNotEmpty)
                Text(
                  order.delivery.postalCode!,
                  style: TextStyle(fontSize: 12, color: c.text3),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Card(
          child: Column(
            children: [
              _TotalRow(
                label: s('seller.orders.gross'),
                value: Money.format(order.sellerGrossAmount),
              ),
              _TotalRow(
                label: s('seller.orders.commission'),
                value: '−${Money.format(order.sellerCommissionAmount)}',
              ),
              const Divider(height: 20),
              _TotalRow(
                label: s('seller.orders.net'),
                value: Money.format(order.sellerNetAmount),
                emphasize: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});
  final SellerOrderItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${item.sku}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.text3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s('order.detail.perUnit')
                        .replaceFirst('{n}', '${item.quantity}')
                        .replaceFirst('{price}', Money.format(item.unitPrice)),
                    style: TextStyle(fontSize: 11.5, color: c.text3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Money.format(item.totalPrice),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                s(
                  'seller.orders.lineCommission',
                ).replaceFirst('{v}', Money.format(item.commissionAmount)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.text3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              s(
                'seller.orders.lineNet',
              ).replaceFirst('{v}', Money.format(item.sellerAmount)),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: c.price,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: emphasize ? 14.5 : 13,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
                color: emphasize ? c.text : c.text2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 16 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? c.price : c.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      letterSpacing: 0.6,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(NovaSpace.md),
      children: const [
        NovaSkeleton(height: 40, margin: EdgeInsets.only(bottom: NovaSpace.md)),
        NovaSkeleton(
          height: 140,
          margin: EdgeInsets.only(bottom: NovaSpace.md),
        ),
        NovaSkeleton(height: 90, margin: EdgeInsets.only(bottom: NovaSpace.md)),
        NovaSkeleton(
          height: 110,
          margin: EdgeInsets.only(bottom: NovaSpace.md),
        ),
      ],
    );
  }
}
