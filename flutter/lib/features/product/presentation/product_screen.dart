import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/localized_text.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_badges.dart';
import '../../../shared/widgets/nova_skeleton.dart';
import '../../../shared/widgets/price_row.dart';
import '../../../shared/widgets/product_card.dart' show deliveryHint;
import '../../../shared/widgets/rating_stars.dart';
import '../../../shared/widgets/section_header.dart';
import '../../reviews/presentation/reviews_section.dart';
import '../data/product_models.dart';
import '../data/product_repository.dart';
import 'widgets/offer_sheet.dart';
import 'widgets/product_gallery.dart';
import 'widgets/product_sticky_bar.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  int? _selectedOfferId;
  bool _descExpanded = false;

  int get _id => int.tryParse(widget.productId) ?? 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final async = ref.watch(productDetailProvider(_id));

    return async.when(
      loading: () => const _ProductSkeleton(),
      error: (e, _) => _isNotFound(e)
          ? _NotFoundScreen()
          : Scaffold(
              appBar: AppBar(),
              body: ErrorView(
                error: e,
                onRetry: () => ref.invalidate(productDetailProvider(_id)),
              ),
            ),
      data: (product) => _loaded(context, s, product),
    );
  }

  Widget _loaded(
    BuildContext context,
    AppStrings s,
    ProductDetailModel product,
  ) {
    final c = context.nova;
    final offersAsync = ref.watch(productOffersProvider(_id));
    final offers = offersAsync.value ?? const [];
    final currentOffer = _currentOffer(product, offers);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(product.brand)),
      bottomNavigationBar: ProductStickyBar(offer: currentOffer),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productDetailProvider(_id));
          ref.invalidate(productOffersProvider(_id));
          await ref.read(productDetailProvider(_id).future);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ProductGallery(images: product.images, heroTag: 'p${product.id}'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand.isNotEmpty)
                    Text(
                      product.brand.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w700,
                        color: c.text3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    s.pick(product.name),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (product.rating > 0)
                        RatingStars(
                          rating: product.rating,
                          reviewCount: product.reviewCount,
                          size: 14,
                        ),
                      const Spacer(),
                      if (currentOffer != null)
                        Text(
                          deliveryHint(currentOffer.deliveryDays, s),
                          style: TextStyle(fontSize: 12, color: c.text3),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (currentOffer != null) ...[
                    PriceRow(
                      price: currentOffer.price,
                      oldPrice: currentOffer.oldPrice,
                      priceSize: 24,
                      oldSize: 14,
                    ),
                    if (currentOffer.discountPercent > 0) ...[
                      const SizedBox(height: 6),
                      DiscountBadge(percent: currentOffer.discountPercent),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      s('product.inStockN').replaceFirst(
                        '{n}',
                        '${currentOffer.availableQuantity}',
                      ),
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                  ] else
                    Text(
                      s('product.notFound.body'),
                      style: TextStyle(color: c.text3),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _OffersRow(
              product: product,
              offers: offers,
              loading: offersAsync.isLoading,
              selectedOfferId: _selectedOfferId ?? product.bestOffer?.offerId,
              onOpen: () => _openOfferSheet(context, offers),
            ),
            const Divider(height: 28),
            _Description(
              text: s.pick(product.description),
              expanded: _descExpanded,
              onToggle: () => setState(() => _descExpanded = !_descExpanded),
              s: s,
            ),
            const Divider(height: 28),
            SectionHeader(
              title: product.reviewCount > 0
                  ? s(
                      'product.reviewsN',
                    ).replaceFirst('{n}', '${product.reviewCount}')
                  : s('product.reviews'),
            ),
            ReviewsSection(productId: _id),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  SellerOfferModel? _currentOffer(
    ProductDetailModel product,
    List<SellerOfferModel> offers,
  ) {
    final id = _selectedOfferId;
    if (id != null) {
      for (final o in offers) {
        if (o.offerId == id) return o;
      }
    }
    return product.bestOffer ?? (offers.isNotEmpty ? offers.first : null);
  }

  Future<void> _openOfferSheet(
    BuildContext context,
    List<SellerOfferModel> offers,
  ) async {
    if (offers.isEmpty) return;
    final picked = await showOfferSheet(
      context,
      offers: offers,
      selectedOfferId:
          _selectedOfferId ??
          ref.read(productDetailProvider(_id)).value?.bestOffer?.offerId,
    );
    if (picked != null) setState(() => _selectedOfferId = picked);
  }

  static bool _isNotFound(Object e) =>
      e is ApiException &&
      (e.kind == ApiErrorKind.notFound || e.code == 'PRODUCT_NOT_FOUND');
}

class _OffersRow extends ConsumerWidget {
  const _OffersRow({
    required this.product,
    required this.offers,
    required this.loading,
    required this.selectedOfferId,
    required this.onOpen,
  });

  final ProductDetailModel product;
  final List<SellerOfferModel> offers;
  final bool loading;
  final int? selectedOfferId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    final count = offers.isNotEmpty ? offers.length : product.sellerCount;
    if (count <= 0 && !loading) return const SizedBox.shrink();

    final cheapest = offers.isNotEmpty
        ? offers.map((o) => o.price).reduce(_minPrice)
        : product.bestOffer?.price;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: loading || offers.isEmpty ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 20, color: c.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s('product.offersN').replaceFirst('{n}', '$count'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      if (cheapest != null)
                        Text(
                          '${s('filter.priceFrom')} ${Money.format(cheapest)}',
                          style: TextStyle(fontSize: 12, color: c.text3),
                        ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: c.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _minPrice(String a, String b) =>
      (double.tryParse(a) ?? 0) <= (double.tryParse(b) ?? 0) ? a : b;
}

class _Description extends StatelessWidget {
  const _Description({
    required this.text,
    required this.expanded,
    required this.onToggle,
    required this.s,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    final body = text.trim().isEmpty ? s('product.noDescription') : text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s('product.aboutProduct'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Text(
              body,
              maxLines: expanded ? null : 4,
              overflow: expanded ? null : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: c.text2),
            ),
          ),
          if (body.length > 180)
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
              ),
              child: Text(expanded ? s('action.close') : s('common.showMore')),
            ),
        ],
      ),
    );
  }
}

class _NotFoundScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        icon: Icons.inventory_2_outlined,
        title: s('product.notFound.title'),
        body: s('product.notFound.body'),
        action: FilledButton(
          onPressed: () => context.go(Routes.catalog),
          child: Text(s('product.toCatalog')),
        ),
      ),
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, double w) => NovaSkeleton(
      height: h,
      width: w,
      radius: NovaRadii.xs,
      margin: const EdgeInsets.only(bottom: NovaSpace.sm),
    );
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const AspectRatio(aspectRatio: 1, child: NovaSkeleton(radius: 0)),
          Padding(
            padding: const EdgeInsets.all(NovaSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(14, 80),
                bar(22, double.infinity),
                bar(22, 220),
                const Gap(NovaSpace.xs),
                bar(28, 160),
                const Gap(NovaSpace.sm),
                bar(56, double.infinity),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
