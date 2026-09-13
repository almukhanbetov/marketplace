import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nova_skeleton.dart';
import '../../../../shared/widgets/nova_text_field.dart';
import '../application/seller_offers_controller.dart';
import '../data/seller_offer_models.dart';
import 'widgets/seller_offer_card.dart';

/// `GET /seller/offers` — real API-backed mobile cards with server-side
/// search / status filter / low-stock filter, infinite scroll and
/// pull-to-refresh. FAB → add offer. (Stage F6B §2/§6/§18.)
class SellerOffersScreen extends ConsumerStatefulWidget {
  const SellerOffersScreen({super.key});

  @override
  ConsumerState<SellerOffersScreen> createState() => _SellerOffersScreenState();
}

class _SellerOffersScreenState extends ConsumerState<SellerOffersScreen> {
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
      ref.read(sellerOffersControllerProvider.notifier).loadMore();
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(sellerOffersControllerProvider.notifier)
          .applyQuery(search: v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(sellerOffersControllerProvider);
    final controller = ref.read(sellerOffersControllerProvider.notifier);

    Widget body;
    if (state.isFirstLoad) {
      body = const _OffersSkeleton();
    } else if (state.status == SellerOffersStatus.error &&
        state.items.isEmpty) {
      body = ErrorView(error: state.error, onRetry: controller.refresh);
    } else if (state.isEmpty && !state.hasFilters) {
      body = _EmptyOffers(onAdd: () => context.push(Routes.sellerOfferNew));
    } else if (state.isEmpty) {
      body = EmptyView(
        icon: Icons.search_off_rounded,
        title: s('seller.offers.noResults'),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
            NovaSpace.md,
            NovaSpace.xs,
            NovaSpace.md,
            96,
          ),
          itemCount:
              state.items.length +
              (state.status == SellerOffersStatus.loadingMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SellerOfferCard(offer: state.items[i]);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.offers.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.sellerOfferNew),
        icon: const Icon(Icons.add_rounded),
        label: Text(s('seller.offers.add')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: NovaTextField(
              label: s('seller.offers.searchHint'),
              controller: _searchCtl,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
            ),
          ),
          _FilterBar(state: state, controller: controller),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.state, required this.controller});
  final SellerOffersState state;
  final SellerOffersController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final f in SellerOfferFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s(f.labelKey)),
                selected: state.filter == f,
                onSelected: (_) => controller.applyQuery(filter: f),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(s('seller.offers.filter.lowStock')),
              selected: state.lowStockOnly,
              onSelected: (v) => controller.applyQuery(lowStockOnly: v),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOffers extends ConsumerWidget {
  const _EmptyOffers({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return EmptyView(
      icon: Icons.sell_outlined,
      title: s('seller.offers.empty.title'),
      body: s('seller.offers.empty.body'),
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(s('seller.offers.add')),
      ),
    );
  }
}

class _OffersSkeleton extends StatelessWidget {
  const _OffersSkeleton();

  @override
  Widget build(BuildContext context) => const NovaSkeletonList(itemHeight: 150);
}
