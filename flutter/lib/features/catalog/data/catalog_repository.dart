import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/paginated.dart';
import '../application/product_query.dart';
import 'catalog_models.dart';

/// Reads the public catalog: `/categories` and `/products`. No auth
/// required (the shared [ApiClient] still sends `X-Client` and a Bearer
/// token if one happens to exist).
class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<List<CategoryModel>> getCategories() async {
    final data = await _api.get('/categories');
    final list = (data as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => CategoryModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<Paginated<ProductCardModel>> getProducts(
    ProductQuery query, {
    CancelToken? cancelToken,
  }) async {
    final res = await _api.getList(
      '/products',
      query: query.toParams(),
      cancelToken: cancelToken,
    );
    final list = (res.data as List?) ?? const [];
    return Paginated(
      items: list
          .whereType<Map>()
          .map((m) => ProductCardModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      meta: res.meta,
    );
  }

  /// The backend has no brand-list endpoint. F3 derives brand options from
  /// a bounded sample of the current result set (respecting the active
  /// category/search so options stay relevant). Documented limitation:
  /// this only surfaces brands present in the first ~100 matching
  /// products, not every brand in the catalog.
  Future<List<String>> sampleBrands(ProductQuery base) async {
    try {
      final res = await _api.getList(
        '/products',
        query:
            base
                .copyWith(
                  brand: null,
                  minPrice: null,
                  maxPrice: null,
                  minRating: null,
                )
                .toParams()
              ..['limit'] = 100
              ..['offset'] = 0,
      );
      final list = (res.data as List?) ?? const [];
      final brands = <String>{
        for (final m in list.whereType<Map>())
          if ((m['brand'] as String?)?.trim().isNotEmpty ?? false)
            (m['brand'] as String).trim(),
      }.toList()..sort();
      return brands;
    } on ApiException {
      return const [];
    }
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});
