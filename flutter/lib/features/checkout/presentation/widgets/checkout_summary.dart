import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/models/localized_text.dart';
import '../../../../shared/widgets/nova_network_image.dart';
import '../../../cart/data/cart_models.dart';

/// Compact, read-only cart view for checkout — product, seller, quantity,
/// line total, grouped by seller (§9). Not the full cart UI; editing
/// happens back in `/cart`.
class CheckoutSummary extends ConsumerWidget {
  const CheckoutSummary({super.key, required this.cart});

  final CartModel cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (var gi = 0; gi < cart.groupedBySeller.length; gi++) ...[
            if (gi > 0) Divider(height: 1, color: c.border),
            _Group(group: cart.groupedBySeller[gi]),
          ],
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Text(
                  s('checkout.items').replaceFirst('{n}', '${cart.itemCount}'),
                  style: TextStyle(fontSize: 12.5, color: c.text2),
                ),
                const Spacer(),
                Text(
                  Money.format(cart.subtotal),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.price,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends ConsumerWidget {
  const _Group({required this.group});
  final CartSellerGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 14, color: c.text2),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  group.seller.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in group.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: NovaNetworkImage(
                      url: item.product.primaryImage,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.pick(item.product.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.25,
                            color: c.text,
                          ),
                        ),
                        Text(
                          '${item.quantity} × ${Money.format(item.price)}',
                          style: TextStyle(fontSize: 11, color: c.text3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Money.format(item.lineTotal),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
