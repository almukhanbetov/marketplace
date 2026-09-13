import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_network_image.dart';
import '../../../shared/widgets/nova_skeleton.dart';
import '../application/orders_controller.dart';
import '../data/order_models.dart';
import 'widgets/order_status_badge.dart';

/// `GET /me/orders/:id`. Ownership is server-enforced — a non-owned id is a
/// 404 `ORDER_NOT_FOUND` and renders as "not found" here (§37/§64). Every
/// value shown is the order's historical snapshot, never today's catalog
/// price or the user's current profile address (§38/§39).
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final id = int.tryParse(orderId);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('order.detail.title'))),
      body: id == null
          ? ErrorView(message: s('error.INVALID_ORDER_ID'))
          : ref
                .watch(orderDetailProvider(id))
                .when(
                  loading: () => const _DetailSkeleton(),
                  error: (e, _) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(orderDetailProvider(id)),
                  ),
                  data: (order) => RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(orderDetailProvider(id)),
                    child: _OrderBody(order: order),
                  ),
                ),
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.order});
  final OrderDetailModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ---- header ----
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
        const SizedBox(height: 20),

        // ---- items grouped by seller ----
        _SectionTitle(s('order.detail.items')),
        for (final group in order.groupedBySeller) ...[
          const SizedBox(height: 8),
          _SellerGroup(group: group),
        ],
        const SizedBox(height: 20),

        // ---- delivery snapshot ----
        _SectionTitle(s('order.detail.delivery')),
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

        // ---- payment ----
        _SectionTitle(s('order.detail.payment')),
        const SizedBox(height: 8),
        _Card(
          child: Row(
            children: [
              Icon(
                order.payment?.provider.icon ?? Icons.payments_outlined,
                size: 20,
                color: c.text2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s(order.payment?.provider.labelKey ?? 'payment.method.card'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              PaymentStatusChip(
                status: order.payment?.status ?? PaymentStatus.unknown,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ---- totals ----
        _Card(
          child: Column(
            children: [
              _TotalRow(
                label: s('checkout.summary.subtotal'),
                value: Money.format(order.subtotal),
              ),
              if (order.discountTotal != '0.00' && order.discountTotal != '0')
                _TotalRow(
                  label: s('checkout.summary.discount'),
                  value: '−${Money.format(order.discountTotal)}',
                ),
              _TotalRow(
                label: s('checkout.summary.delivery'),
                value:
                    (order.deliveryTotal == '0.00' ||
                        order.deliveryTotal == '0')
                    ? s('checkout.summary.deliveryFree')
                    : Money.format(order.deliveryTotal),
              ),
              const Divider(height: 20),
              _TotalRow(
                label: s('order.detail.total'),
                value: Money.format(order.total),
                emphasize: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SellerGroup extends ConsumerWidget {
  const _SellerGroup({required this.group});
  final OrderSellerGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 15, color: c.text2),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  group.sellerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0) Divider(height: 16, color: c.border),
            _ItemRow(
              item: group.items[i],
              perUnitLabel: s('order.detail.perUnit'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.perUnitLabel});
  final OrderItemModel item;
  final String perUnitLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: NovaNetworkImage(
            url: item.primaryImage,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.25, color: c.text),
              ),
              const SizedBox(height: 3),
              Text(
                perUnitLabel
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
            color: c.price,
          ),
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
          height: 120,
          margin: EdgeInsets.only(bottom: NovaSpace.md),
        ),
        NovaSkeleton(height: 96, margin: EdgeInsets.only(bottom: NovaSpace.md)),
        NovaSkeleton(
          height: 120,
          margin: EdgeInsets.only(bottom: NovaSpace.md),
        ),
      ],
    );
  }
}
