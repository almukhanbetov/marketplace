import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/localized_text.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/nova_network_image.dart';
import '../application/seller_offers_controller.dart';
import '../data/seller_offer_models.dart';
import 'widgets/offer_form.dart';

/// Edit an existing offer — only the four backend-mutable fields (SKU,
/// price, old price, delivery days). The product and seller can never be
/// reassigned here (Stage F6B §11). The [offer] arrives via route `extra`
/// from the offers list.
class EditOfferScreen extends ConsumerWidget {
  const EditOfferScreen({super.key, required this.offer});

  final SellerOfferModel? offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final o = offer;

    if (o == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(s('seller.offers.edit'))),
        body: EmptyView(
          icon: Icons.error_outline_rounded,
          title: s('seller.offers.editUnavailable'),
          action: FilledButton(
            onPressed: () => context.go(Routes.sellerOffers),
            child: Text(s('seller.offers.title')),
          ),
        ),
      );
    }

    Future<String?> submit(OfferFormValues v) async {
      try {
        await ref
            .read(sellerOffersControllerProvider.notifier)
            .editOffer(
              o.id,
              EditOfferInput(
                sku: v.sku,
                price: v.price,
                oldPrice: v.oldPrice,
                deliveryDays: v.deliveryDays,
              ),
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(s('seller.offers.saved'))));
          context.pop();
        }
        return null;
      } on ApiException catch (e) {
        return s.apiError(e.code);
      }
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.offers.edit'))),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: NovaNetworkImage(
                      url: o.primaryImage,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.pick(o.productName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            OfferForm(
              submitLabel: s('action.save'),
              initialSku: o.sku,
              initialPrice: o.price,
              initialOldPrice: o.oldPrice ?? '',
              initialDeliveryDays: o.deliveryDays,
              onSubmit: submit,
            ),
          ],
        ),
      ),
    );
  }
}
