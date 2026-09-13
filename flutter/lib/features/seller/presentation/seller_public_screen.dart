import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/localized_text.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_badges.dart';
import '../../../shared/widgets/product_grid.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../catalog/data/catalog_models.dart';
import '../application/seller_products_provider.dart';
import '../data/seller_public_models.dart';
import '../data/seller_public_repository.dart';

/// Public seller storefront (`/seller/:id`, §41–§43). Header card +
/// seller-specific-priced product grid. Anonymous access is fine.
class SellerPublicScreen extends ConsumerStatefulWidget {
  const SellerPublicScreen({super.key, required this.sellerId});

  final int sellerId;

  @override
  ConsumerState<SellerPublicScreen> createState() => _SellerPublicScreenState();
}

class _SellerPublicScreenState extends ConsumerState<SellerPublicScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(sellerProductsProvider(widget.sellerId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final detail = ref.watch(sellerDetailProvider(widget.sellerId));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(detail.value?.name ?? s('seller.storeTitle'))),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _isNotFound(e)
            ? EmptyView(
                icon: Icons.storefront_outlined,
                title: s('seller.notFound.title'),
                action: FilledButton(
                  onPressed: () => context.go(Routes.catalog),
                  child: Text(s('nav.catalog')),
                ),
              )
            : ErrorView(
                error: e,
                onRetry: () =>
                    ref.invalidate(sellerDetailProvider(widget.sellerId)),
              ),
        data: (seller) => _content(context, s, seller),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppStrings s,
    SellerDetailModel seller,
  ) {
    final products = ref.watch(sellerProductsProvider(widget.sellerId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sellerDetailProvider(widget.sellerId));
        await ref
            .read(sellerProductsProvider(widget.sellerId).notifier)
            .refresh();
      },
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: _Header(seller: seller, s: s),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                s('seller.products'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (products.isFirstLoad)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (products.status == PagedStatus.error &&
              products.items.isEmpty)
            SliverToBoxAdapter(
              child: ErrorView(
                error: products.error,
                onRetry: ref
                    .read(sellerProductsProvider(widget.sellerId).notifier)
                    .refresh,
              ),
            )
          else if (products.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Text(
                    s('seller.noProducts'),
                    style: TextStyle(color: context.nova.text2),
                  ),
                ),
              ),
            )
          else
            SliverProductGrid(
              products: [
                for (final p in products.items) _asCard(p, seller.name),
              ],
            ),
          SliverToBoxAdapter(child: _footer(products)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _footer(SellerProductsState st) {
    if (st.status == PagedStatus.loadingMore ||
        (st.hasMore && !st.isFirstLoad)) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  static ProductCardModel _asCard(SellerProductModel p, String sellerName) {
    return ProductCardModel(
      id: p.productId,
      slug: p.slug,
      brand: p.brand,
      name: p.name,
      category: const CategoryRefModel(
        id: 0,
        slug: '',
        name: LocalizedText.empty,
      ),
      rating: p.rating,
      reviewCount: p.reviewCount,
      primaryImage: p.primaryImage,
      price: p.price, // THIS seller's price (§42)
      oldPrice: p.oldPrice,
      discountPercent: p.discountPercent,
      bestOfferId: p.offerId,
      sellerName: sellerName,
      sellerRating: 0,
      sellerCount: 1,
      minDeliveryDays: p.deliveryDays,
    );
  }

  static bool _isNotFound(Object e) =>
      e is ApiException &&
      (e.kind == ApiErrorKind.notFound || e.code == 'SELLER_NOT_FOUND');
}

class _Header extends StatelessWidget {
  const _Header({required this.seller, required this.s});
  final SellerDetailModel seller;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.accentSoft,
                child: Text(
                  seller.name.isNotEmpty ? seller.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: c.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            seller.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (seller.isVerified) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    RatingStars(
                      rating: seller.rating,
                      reviewCount: seller.reviewCount,
                      size: 13,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!seller.isActive) ...[
            const SizedBox(height: 10),
            Text(
              s('seller.inactive'),
              style: TextStyle(color: c.warning, fontSize: 12.5),
            ),
          ],
          if (seller.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              seller.description,
              style: TextStyle(fontSize: 13, height: 1.4, color: c.text2),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(
                context,
                s(
                  'seller.productsN',
                ).replaceFirst('{n}', '${seller.productCount}'),
              ),
              const SizedBox(width: 16),
              _stat(
                context,
                s(
                  'seller.reviewsN',
                ).replaceFirst('{n}', '${seller.reviewCount}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String text) =>
      Text(text, style: TextStyle(fontSize: 12, color: context.nova.text3));
}
