import '../../../shared/constants/app_constants.dart';

/// Backend product sort whitelist (`services.ParseProductQuery`).
enum ProductSort {
  relevance('', 'sort.relevance'),
  priceAsc('price_asc', 'sort.priceAsc'),
  priceDesc('price_desc', 'sort.priceDesc'),
  ratingDesc('rating_desc', 'sort.ratingDesc'),
  newest('newest', 'sort.newest'),
  discountDesc('discount_desc', 'sort.discountDesc');

  const ProductSort(this.apiValue, this.labelKey);

  /// Empty for [relevance] — the param is simply omitted.
  final String apiValue;
  final String labelKey;

  static ProductSort fromApi(String? v) => values.firstWhere(
    (s) => s.apiValue == v,
    orElse: () => ProductSort.relevance,
  );
}

/// The fully typed catalog query. The UI maps its state into this; the
/// repository maps this to query params. No widget builds a query string.
class ProductQuery {
  const ProductQuery({
    this.search = '',
    this.categorySlug,
    this.sellerId,
    this.brand,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.sort = ProductSort.relevance,
    this.limit = AppConstants.pageSize,
    this.offset = 0,
  });

  final String search;
  final String? categorySlug;
  final int? sellerId;
  final String? brand;

  /// Decimal strings ("100000", "100000.00") — validated numeric before set.
  final String? minPrice;
  final String? maxPrice;

  /// 1–5.
  final int? minRating;

  final ProductSort sort;
  final int limit;
  final int offset;

  /// True when anything beyond search/sort/pagination is set — drives the
  /// "filters active" dot and the Reset button.
  bool get hasActiveFilters =>
      (categorySlug != null && categorySlug!.isNotEmpty) ||
      (brand != null && brand!.isNotEmpty) ||
      (minPrice != null && minPrice!.isNotEmpty) ||
      (maxPrice != null && maxPrice!.isNotEmpty) ||
      minRating != null;

  int get activeFilterCount => [
    categorySlug?.isNotEmpty ?? false,
    brand?.isNotEmpty ?? false,
    minPrice?.isNotEmpty ?? false,
    maxPrice?.isNotEmpty ?? false,
    minRating != null,
  ].where((b) => b).length;

  /// Identity key for stale-response detection — everything except offset.
  String get identity => [
    search,
    categorySlug ?? '',
    sellerId ?? '',
    brand ?? '',
    minPrice ?? '',
    maxPrice ?? '',
    minRating ?? '',
    sort.apiValue,
  ].join('|');

  Map<String, dynamic> toParams() => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (categorySlug != null && categorySlug!.isNotEmpty)
      'category': categorySlug,
    if (sellerId != null) 'seller': sellerId,
    if (brand != null && brand!.isNotEmpty) 'brand': brand,
    if (minPrice != null && minPrice!.isNotEmpty) 'min_price': minPrice,
    if (maxPrice != null && maxPrice!.isNotEmpty) 'max_price': maxPrice,
    if (minRating != null) 'rating': minRating,
    if (sort.apiValue.isNotEmpty) 'sort': sort.apiValue,
    'limit': limit,
    'offset': offset,
  };

  ProductQuery copyWith({
    String? search,
    Object? categorySlug = _keep,
    Object? sellerId = _keep,
    Object? brand = _keep,
    Object? minPrice = _keep,
    Object? maxPrice = _keep,
    Object? minRating = _keep,
    ProductSort? sort,
    int? limit,
    int? offset,
  }) {
    return ProductQuery(
      search: search ?? this.search,
      categorySlug: categorySlug == _keep
          ? this.categorySlug
          : categorySlug as String?,
      sellerId: sellerId == _keep ? this.sellerId : sellerId as int?,
      brand: brand == _keep ? this.brand : brand as String?,
      minPrice: minPrice == _keep ? this.minPrice : minPrice as String?,
      maxPrice: maxPrice == _keep ? this.maxPrice : maxPrice as String?,
      minRating: minRating == _keep ? this.minRating : minRating as int?,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  /// Drop every filter, keep search + sort + a fresh page.
  ProductQuery cleared() =>
      ProductQuery(search: search, sort: sort, limit: limit);

  static const _keep = Object();
}
