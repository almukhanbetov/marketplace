import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/api_exception.dart';
import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/models/localized_text.dart';
import '../../../../../shared/widgets/empty_view.dart';
import '../../../../../shared/widgets/error_view.dart';
import '../../../../../shared/widgets/nova_network_image.dart';
import '../../../../../shared/widgets/nova_text_field.dart';
import '../../../../catalog/application/product_query.dart';
import '../../../../catalog/data/catalog_models.dart';
import '../../../../catalog/data/catalog_repository.dart';

/// Full-screen picker over the **public catalog** — the seller adds an
/// offer against an existing global product, never a new one (Stage F6B
/// §7/§8). Backend search + pagination; the catalog is never loaded whole.
/// Returns the chosen [ProductCardModel] via `Navigator.pop`.
class ProductSelectorScreen extends ConsumerStatefulWidget {
  const ProductSelectorScreen({super.key});

  @override
  ConsumerState<ProductSelectorScreen> createState() =>
      _ProductSelectorScreenState();
}

class _ProductSelectorScreenState extends ConsumerState<ProductSelectorScreen> {
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();
  Timer? _debounce;

  static const _pageSize = 20;
  String _query = '';
  int _generation = 0;
  final _items = <ProductCardModel>[];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (v.trim() == _query) return;
      _query = v.trim();
      _load();
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400 &&
        !_loadingMore &&
        !_loading &&
        _items.length < _total) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(catalogRepositoryProvider)
          .getProducts(ProductQuery(search: _query, limit: _pageSize));
      if (gen != _generation || !mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.meta.total;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (gen != _generation || !mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(catalogRepositoryProvider)
          .getProducts(
            ProductQuery(
              search: _query,
              limit: _pageSize,
              offset: _items.length,
            ),
          );
      if (gen != _generation || !mounted) return;
      final seen = _items.map((p) => p.id).toSet();
      setState(() {
        _items.addAll(page.items.where((p) => seen.add(p.id)));
        _total = page.meta.total;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = ErrorView(error: _error, onRetry: _load);
    } else if (_items.isEmpty) {
      body = EmptyView(
        icon: Icons.search_off_rounded,
        title: s('seller.offers.productSelect.empty'),
      );
    } else {
      body = ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length + (_items.length < _total ? 1 : 0),
        separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final p = _items[i];
          return ListTile(
            leading: SizedBox(
              width: 44,
              height: 44,
              child: NovaNetworkImage(
                url: p.primaryImage,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            title: Text(
              s.pick(p.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
            subtitle: Text(
              p.brand,
              style: TextStyle(fontSize: 11.5, color: c.text3),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(p),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.offers.productSelect.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: NovaTextField(
              label: s('seller.offers.productSelect.searchHint'),
              controller: _searchCtl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
