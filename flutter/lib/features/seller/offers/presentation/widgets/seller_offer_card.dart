import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/errors/api_exception.dart';
import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/router/routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../shared/models/localized_text.dart';
import '../../../../../shared/widgets/nova_feedback.dart';
import '../../../../../shared/widgets/nova_network_image.dart';
import '../../../../../shared/widgets/price_row.dart';
import '../../application/seller_offers_controller.dart';
import '../../data/seller_offer_models.dart';

/// One seller offer as a mobile card (Stage F6B §6) — image, product, SKU,
/// price/old price, stock, delivery, active status, and Edit /
/// Activate-Deactivate actions. Never part of a table.
class SellerOfferCard extends ConsumerWidget {
  const SellerOfferCard({super.key, required this.offer});

  final SellerOfferModel offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final busy = ref.watch(
      sellerOffersControllerProvider.select(
        (st) => st.mutating.contains(offer.id),
      ),
    );

    Future<void> toggle() async {
      try {
        await ref
            .read(sellerOffersControllerProvider.notifier)
            .setActive(offer.id, active: !offer.isActive);
      } on ApiException catch (e) {
        if (context.mounted) NovaSnackbar.error(context, s.apiError(e.code));
      }
    }

    return Opacity(
      opacity: offer.isActive ? 1 : 0.62,
      child: Container(
        margin: const EdgeInsets.only(bottom: NovaSpace.sm),
        padding: const EdgeInsets.all(NovaSpace.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(NovaRadii.md),
          border: Border.all(color: c.border),
          boxShadow: offer.isActive
              ? NovaShadows.card(Theme.of(context).brightness)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: NovaNetworkImage(
                    url: offer.primaryImage,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.pick(offer.productName),
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
                        'SKU: ${offer.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.text3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(active: offer.isActive),
              ],
            ),
            const SizedBox(height: 10),
            PriceRow(
              price: offer.price,
              oldPrice: offer.hasOldPrice ? offer.oldPrice : null,
              priceSize: 15,
              oldSize: 11.5,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Meta(
                  icon: Icons.inventory_2_outlined,
                  text: s(
                    'seller.offers.stockN',
                  ).replaceFirst('{n}', '${offer.availableQuantity}'),
                  tone: offer.isLowStock ? c.warning : c.text2,
                ),
                _Meta(
                  icon: Icons.local_shipping_outlined,
                  text: s(
                    'seller.offers.deliveryN',
                  ).replaceFirst('{n}', '${offer.deliveryDays}'),
                  tone: c.text2,
                ),
                if (offer.reservedQuantity > 0)
                  _Meta(
                    icon: Icons.lock_clock_outlined,
                    text: s(
                      'seller.offers.reservedN',
                    ).replaceFirst('{n}', '${offer.reservedQuantity}'),
                    tone: c.text3,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => context.push(
                            Routes.sellerOfferEdit(offer.id),
                            extra: offer,
                          ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      s('action.edit'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: busy
                      ? const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(
                          onPressed: toggle,
                          child: Text(
                            offer.isActive
                                ? s('seller.offers.deactivate')
                                : s('seller.offers.activate'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: offer.isActive ? c.danger : c.success,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final color = active ? c.success : c.text3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(appStringsProvider);
          return Text(
            active
                ? s('seller.offers.status.active')
                : s('seller.offers.status.inactive'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.tone});
  final IconData icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: tone),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: tone,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
