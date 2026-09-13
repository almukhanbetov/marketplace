import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/application/product_query.dart';
import '../../catalog/data/catalog_models.dart';
import '../../catalog/data/catalog_repository.dart';

/// One home rail's outcome — data or a (recoverable) failure. A failed
/// section renders its own retry without taking down the page (§9/§10).
class HomeSection {
  const HomeSection({
    required this.titleKey,
    this.items = const [],
    this.failed = false,
  });

  final String titleKey;
  final List<ProductCardModel> items;
  final bool failed;

  bool get isEmpty => items.isEmpty && !failed;
}

class HomeData {
  const HomeData({
    required this.categories,
    required this.categoriesFailed,
    required this.forYou,
    required this.popular,
    required this.discount,
    required this.newest,
  });

  final List<CategoryModel> categories;
  final bool categoriesFailed;
  final HomeSection forYou;
  final HomeSection popular;
  final HomeSection discount;
  final HomeSection newest;

  List<HomeSection> get rails => [forYou, popular, discount, newest];
}

/// Kept alive for the session; pull-to-refresh does `ref.invalidate`.
final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);

  Future<HomeSection> section(String titleKey, ProductSort sort) async {
    try {
      final page = await repo.getProducts(ProductQuery(sort: sort, limit: 10));
      return HomeSection(titleKey: titleKey, items: page.items);
    } on Object {
      return HomeSection(titleKey: titleKey, failed: true);
    }
  }

  Future<(List<CategoryModel>, bool)> categories() async {
    try {
      return (await repo.getCategories(), false);
    } on Object {
      return (<CategoryModel>[], true);
    }
  }

  // All sections + categories in parallel — home is never blocked behind
  // one sequential chain.
  final results = await Future.wait([
    categories(),
    section('home.rail.forYou', ProductSort.relevance),
    section('home.rail.popular', ProductSort.ratingDesc),
    section('home.rail.discount', ProductSort.discountDesc),
    section('home.rail.newest', ProductSort.newest),
  ]);

  final (cats, catsFailed) = results[0] as (List<CategoryModel>, bool);
  return HomeData(
    categories: cats.where((c) => c.isRoot).toList(),
    categoriesFailed: catsFailed,
    forYou: results[1] as HomeSection,
    popular: results[2] as HomeSection,
    discount: results[3] as HomeSection,
    newest: results[4] as HomeSection,
  );
});
