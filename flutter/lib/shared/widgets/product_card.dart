import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/localization/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../features/catalog/data/catalog_models.dart';
import '../../features/favorites/application/favorites_controller.dart';
import '../models/localized_text.dart';
import 'nova_badges.dart';
import 'nova_feedback.dart';
import 'nova_network_image.dart';
import 'price_row.dart';
import 'rating_stars.dart';

/// The one reusable product card — the catalog grid (fills its cell) and
/// home rails (fixed [width]). Tapping opens the product detail. The
/// favourite heart is visual only in F3 (real in F4, §28).
///
/// Overflow-safe by construction: the image is a fixed 1:1 box, and the
/// text block is an `Expanded` region whose content is clipped, never
/// forced — so long RU/KAZ names can never blow the layout (§56/§57).
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, this.width});

  final ProductCardModel product;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final name = s.pick(product.name);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(NovaRadii.md),
        border: Border.all(color: c.border),
        boxShadow: NovaShadows.card(Theme.of(context).brightness),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(NovaRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.product(product.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImageArea(product: product, name: name),
              Expanded(
                child: ClipRect(
                  child: SingleChildScrollView(
                    // Deterministic clip: content that (with a very long
                    // RU/KAZ name) would exceed the grid cell is trimmed
                    // rather than throwing a RenderFlex overflow (§56/§57).
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        NovaSpace.sm,
                        NovaSpace.xs,
                        NovaSpace.sm,
                        NovaSpace.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (product.brand.isNotEmpty)
                            Text(
                              product.brand.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: c.text3,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.22,
                              color: c.text,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (product.rating > 0)
                            RatingStars(
                              rating: product.rating,
                              reviewCount: product.reviewCount,
                              size: 11.5,
                            ),
                          const SizedBox(height: 6),
                          PriceRow(
                            price: product.price,
                            oldPrice: product.oldPrice,
                            priceSize: 14.5,
                            oldSize: 11,
                          ),
                          const SizedBox(height: 3),
                          _MetaLine(product: product, s: s),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (width == null) return card;
    return SizedBox(width: width, child: card);
  }
}

class _ImageArea extends StatelessWidget {
  const _ImageArea({required this.product, required this.name});
  final ProductCardModel product;
  final String name;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            label: name,
            image: true,
            child: NovaNetworkImage(
              url: product.primaryImage,
              fit: BoxFit.cover,
            ),
          ),
          if (product.discountPercent > 0)
            Positioned(
              top: 8,
              left: 8,
              child: DiscountBadge(
                percent: product.discountPercent,
                compact: true,
              ),
            ),
          Positioned(top: 1, right: 1, child: _FavHeart(product: product)),
        ],
      ),
    );
  }
}

/// Real favourite toggle (Stage F4 §7/§8). Optimistic via
/// `FavoritesController`; anonymous tap routes to login.
class _FavHeart extends ConsumerWidget {
  const _FavHeart({required this.product});
  final ProductCardModel product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final authed = ref.watch(
      authControllerProvider.select((a) => a.isAuthenticated),
    );
    final isFav = authed && ref.watch(isFavoriteProvider(product.id));

    Future<void> onTap() async {
      if (!authed) {
        GoRouter.of(context).go(
          '${Routes.login}?from=${Uri.encodeComponent(GoRouterState.of(context).matchedLocation)}',
        );
        return;
      }
      try {
        await ref
            .read(favoritesControllerProvider.notifier)
            .toggle(product.id, known: product);
      } on Object {
        if (context.mounted) {
          NovaSnackbar.error(context, s('error.UNKNOWN_ERROR'));
        }
      }
    }

    return Semantics(
      button: true,
      toggled: isFav,
      label: s('nav.favorites'),
      child: IconButton(
        onPressed: onTap,
        iconSize: 19,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: c.surface.withValues(alpha: 0.82),
          minimumSize: const Size(34, 34),
        ),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(isFav),
            color: isFav ? c.danger : c.text2,
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.product, required this.s});
  final ProductCardModel product;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final parts = <String>[
      if (product.sellerCount > 1)
        s('product.sellersN').replaceFirst('{n}', '${product.sellerCount}')
      else if (product.sellerName.isNotEmpty)
        product.sellerName,
      deliveryHint(product.minDeliveryDays, s),
    ].where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10.5, color: c.text3),
    );
  }
}

String deliveryHint(int days, AppStrings s) => switch (days) {
  0 => s('product.deliveryToday'),
  1 => s('product.deliveryTomorrow'),
  _ => s('product.deliveryDays').replaceFirst('{n}', '$days'),
};
