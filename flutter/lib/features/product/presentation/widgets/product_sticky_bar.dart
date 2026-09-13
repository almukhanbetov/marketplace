import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/nova_feedback.dart';
import '../../../../shared/widgets/nova_sticky_bar.dart';
import '../../../../shared/widgets/price_row.dart';
import '../../../cart/application/cart_controller.dart';
import '../../data/product_models.dart';

/// Sticky bottom CTA. F4 activates it against the real cart (§16):
///  - "В корзину"  → add the **selected** offer, toast, badge updates.
///  - "Купить сейчас" → add + navigate to `/cart` (checkout is F5).
/// Logged-out users are routed to login first. No fake state, no order.
class ProductStickyBar extends ConsumerWidget {
  const ProductStickyBar({super.key, required this.offer});

  /// `offer.offerId` is the `seller_offer_id` sent to the cart (§61) —
  /// never `offer.sellerId`.
  final SellerOfferModel? offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final authed = ref.watch(
      authControllerProvider.select((a) => a.isAuthenticated),
    );
    final adding = ref.watch(cartControllerProvider.select((st) => st.adding));

    if (offer == null) return const SizedBox.shrink();
    final o = offer!;
    final soldOut = o.availableQuantity <= 0;

    void toLogin() => context.push(
      '${Routes.login}?from=${Uri.encodeComponent(GoRouterState.of(context).matchedLocation)}',
    );

    Future<bool> add() async {
      try {
        await ref.read(cartControllerProvider.notifier).addOffer(o.offerId);
        return true;
      } on ApiException catch (e) {
        if (context.mounted) NovaSnackbar.error(context, s.apiError(e.code));
        return false;
      }
    }

    Future<void> onAddToCart() async {
      if (!authed) return toLogin();
      if (await add() && context.mounted) {
        NovaSnackbar.success(context, s('cart.added'));
      }
    }

    // "Купить сейчас": ensure this offer is in the cart, then go straight
    // to checkout (§43). If the offer is already a cart line we do NOT
    // re-POST it — that would silently bump its quantity.
    Future<void> onBuyNow() async {
      if (!authed) return toLogin();
      final alreadyInCart = ref
          .read(cartControllerProvider)
          .cart
          .items
          .any((it) => it.sellerOfferId == o.offerId);
      if (!alreadyInCart && !await add()) return;
      if (context.mounted) context.push(Routes.checkout);
    }

    Widget label(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    // Price + seller on their own line above two full-width CTAs. Stacking
    // them (rather than sharing one row) is what keeps "Купить сейчас"
    // from truncating on a 360–411dp screen or at a large font scale
    // (Stage F7B — verified on device).
    return NovaStickyBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              PriceRow(
                price: o.price,
                oldPrice: o.oldPrice,
                priceSize: 16,
                wrap: false,
              ),
              const SizedBox(width: NovaSpace.xs),
              Expanded(
                child: Text(
                  o.sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.text3),
                ),
              ),
            ],
          ),
          const Gap(NovaSpace.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: adding || soldOut ? null : onAddToCart,
                  child: adding
                      ? const _Spinner()
                      : label(s('product.addToCart')),
                ),
              ),
              const SizedBox(width: NovaSpace.xs),
              Expanded(
                child: FilledButton(
                  onPressed: adding || soldOut ? null : onBuyNow,
                  child: label(s('product.buyNow')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
