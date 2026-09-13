import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/models/paginated.dart';
import 'seller_public_models.dart';

/// Reads the PUBLIC seller storefront: `/sellers/:id` and
/// `/sellers/:id/products`. The private `/seller/*` dashboard is a
/// different, auth-gated feature (Stage F6).
class SellerPublicRepository {
  SellerPublicRepository(this._api);

  final ApiClient _api;

  Future<SellerDetailModel> getSeller(int id) async {
    final data = await _api.get('/sellers/$id');
    return SellerDetailModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Paginated<SellerProductModel>> getSellerProducts(
    int id, {
    int offset = 0,
    int limit = AppConstants.pageSize,
  }) async {
    final res = await _api.getList(
      '/sellers/$id/products',
      query: {'limit': limit, 'offset': offset},
    );
    final list = (res.data as List?) ?? const [];
    return Paginated(
      items: list
          .whereType<Map>()
          .map((m) => SellerProductModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      meta: res.meta,
    );
  }
}

final sellerPublicRepositoryProvider = Provider<SellerPublicRepository>((ref) {
  return SellerPublicRepository(ref.watch(apiClientProvider));
});

final sellerDetailProvider = FutureProvider.autoDispose
    .family<SellerDetailModel, int>((ref, id) {
      return ref.watch(sellerPublicRepositoryProvider).getSeller(id);
    });
