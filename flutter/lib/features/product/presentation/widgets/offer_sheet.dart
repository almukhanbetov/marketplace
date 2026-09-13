import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/nova_badges.dart';
import '../../../../shared/widgets/price_row.dart';
import '../../../../shared/widgets/rating_stars.dart';
import '../../data/product_models.dart';

/// Multi-seller offer picker (§37/§38). Highlights the best offer (the
/// first — backend order is price asc, then rating), lets the user select
/// one, and returns the chosen `offerId`. Selection is local to the
/// product detail; nothing is added to a cart in F3.
Future<int?> showOfferSheet(
  BuildContext context, {
  required List<SellerOfferModel> offers,
  required int? selectedOfferId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _OfferSheet(offers: offers, selectedOfferId: selectedOfferId),
  );
}

class _OfferSheet extends ConsumerWidget {
  const _OfferSheet({required this.offers, required this.selectedOfferId});

  final List<SellerOfferModel> offers;
  final int? selectedOfferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                s('offer.title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                itemCount: offers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final o = offers[i];
                  final selected = o.offerId == selectedOfferId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, o.offerId),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? c.accentSoft : c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? c.accent : c.border,
                          width: selected ? 1.4 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (i == 0)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.success,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    s('product.bestOffer'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  o.sellerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (o.sellerVerified) ...[
                                const SizedBox(width: 4),
                                const VerifiedBadge(),
                              ],
                              const Spacer(),
                              if (selected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: c.accent,
                                  size: 20,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              RatingStars(
                                rating: o.sellerRating,
                                showCount: false,
                                size: 12,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                s(
                                  'offer.deliveryN',
                                ).replaceFirst('{n}', '${o.deliveryDays}'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: c.text3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              PriceRow(
                                price: o.price,
                                oldPrice: o.oldPrice,
                                priceSize: 15,
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () =>
                                    context.push(Routes.seller(o.sellerId)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: Text(s('product.goToSeller')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
