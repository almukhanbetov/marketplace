import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/models/localized_text.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_skeleton.dart';
import '../../../shared/widgets/product_grid.dart';
import '../application/catalog_providers.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/sort_sheet.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  String? _appliedParams;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // React to `?category=`, `?q=`, `?focus=1` — from Home, categories, etc.
    final params = GoRouterState.of(context).uri.queryParameters;
    final key = '${params['q']}|${params['category']}|${params['focus']}';
    if (key == _appliedParams) return;
    _appliedParams = key;

    final controller = ref.read(catalogControllerProvider.notifier);
    final q = params['q'];
    final category = params['category'];
    if (q != null || category != null) {
      var query = ref.read(catalogControllerProvider).query;
      if (category != null) query = query.copyWith(categorySlug: category);
      if (q != null) {
        query = query.copyWith(search: q);
        _searchCtl.text = q;
      }
      controller.applyQuery(query.copyWith(offset: 0));
    }
    if (params['focus'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _searchFocus.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(catalogControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(catalogControllerProvider);
    final controller = ref.read(catalogControllerProvider.notifier);

    // Keep the field in sync if the query's search was changed elsewhere.
    if (_searchCtl.text != state.query.search && !_searchFocus.hasFocus) {
      _searchCtl.text = state.query.search;
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: 12,
        title: _SearchField(
          controller: _searchCtl,
          focusNode: _searchFocus,
          hint: s('catalog.searchHint'),
          onChanged: controller.onSearchChanged,
          onSubmitted: controller.submitSearch,
          onClear: () {
            _searchCtl.clear();
            controller.submitSearch('');
          },
        ),
      ),
      body: Column(
        children: [
          _ControlBar(state: state),
          if (state.query.hasActiveFilters) _FilterChips(state: state),
          Expanded(
            child: _Results(state: state, scroll: _scroll),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(fontSize: 14, color: c.text),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: c.surface2,
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.text3),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onClear,
                  ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.state});
  final CatalogState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final controller = ref.read(catalogControllerProvider.notifier);
    final count = state.total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state.status == CatalogStatus.loading && state.items.isEmpty
                  ? ''
                  : s('catalog.resultsCount').replaceFirst('{n}', '$count'),
              style: TextStyle(color: c.text2, fontSize: 12.5),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final sort = await showSortSheet(
                context,
                current: state.query.sort,
              );
              if (sort != null) controller.setSort(sort);
            },
            icon: const Icon(Icons.swap_vert_rounded, size: 18),
            label: Text(s('catalog.sort')),
          ),
          TextButton.icon(
            onPressed: () async {
              final categories = ref.read(rootCategoriesProvider);
              final q = await showFilterSheet(
                context,
                query: state.query,
                categories: categories,
                brands: state.brands,
              );
              if (q != null) controller.applyQuery(q);
            },
            icon: Badge(
              isLabelVisible: state.query.activeFilterCount > 0,
              label: Text('${state.query.activeFilterCount}'),
              child: const Icon(Icons.tune_rounded, size: 18),
            ),
            label: Text(s('catalog.filters')),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.state});
  final CatalogState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final controller = ref.read(catalogControllerProvider.notifier);
    final q = state.query;
    final categories = ref.watch(rootCategoriesProvider);

    String? categoryName;
    if (q.categorySlug != null) {
      final match = categories.where((c) => c.slug == q.categorySlug);
      categoryName = match.isEmpty ? q.categorySlug : s.pick(match.first.name);
    }

    final chips = <Widget>[
      if (categoryName != null)
        _Chip(
          label: categoryName,
          onRemoved: () =>
              controller.applyQuery(q.copyWith(categorySlug: null)),
        ),
      if (q.brand != null && q.brand!.isNotEmpty)
        _Chip(
          label: q.brand!,
          onRemoved: () => controller.applyQuery(q.copyWith(brand: null)),
        ),
      if ((q.minPrice ?? '').isNotEmpty || (q.maxPrice ?? '').isNotEmpty)
        _Chip(
          label:
              '${s('filter.priceFrom')} ${q.minPrice ?? '0'} — ${q.maxPrice ?? '∞'}',
          onRemoved: () =>
              controller.applyQuery(q.copyWith(minPrice: null, maxPrice: null)),
        ),
      if (q.minRating != null)
        _Chip(
          label: s('filter.ratingN').replaceFirst('{n}', '${q.minRating}'),
          onRemoved: () => controller.applyQuery(q.copyWith(minRating: null)),
        ),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          ...chips.expand((w) => [w, const SizedBox(width: 8)]),
          ActionChip(
            label: Text(s('catalog.clearFilters')),
            onPressed: controller.resetFilters,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemoved});
  final String label;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      onDeleted: onRemoved,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.state, required this.scroll});
  final CatalogState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final controller = ref.read(catalogControllerProvider.notifier);

    if (state.isFirstLoad) return const _GridSkeleton();

    if (state.status == CatalogStatus.error && state.items.isEmpty) {
      return ErrorView(error: state.error, onRetry: controller.refresh);
    }

    if (state.isEmpty) {
      final q = state.query.search.trim();
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: s('catalog.noResults.title'),
        body: q.isNotEmpty
            ? s('catalog.searchNothing').replaceFirst('{q}', q)
            : s('catalog.noResults.body'),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverProductGrid(products: state.items),
          SliverToBoxAdapter(
            child: _Footer(state: state, onRetry: controller.loadMore),
          ),
        ],
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state, required this.onRetry});
  final CatalogState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    if (state.status == CatalogStatus.errorMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(s('catalog.loadMoreError')),
          ),
        ),
      );
    }
    if (state.status == CatalogStatus.loadingMore || state.hasMore) {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Center(
        child: Text(
          '· ${state.items.length} / ${state.total} ·',
          style: TextStyle(color: c.text3, fontSize: 11.5),
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.sm,
        NovaSpace.xs,
        NovaSpace.sm,
        NovaSpace.xs,
      ),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: NovaSpace.sm,
        mainAxisSpacing: NovaSpace.sm,
        childAspectRatio: 0.58,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const NovaSkeleton(radius: NovaRadii.md),
    );
  }
}
