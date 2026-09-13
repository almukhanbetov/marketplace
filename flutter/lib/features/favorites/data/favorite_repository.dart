import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../catalog/data/catalog_models.dart';

/// `/me/favorites`. The list endpoint returns the **same** shape as
/// `/products` (a product card), so favourites reuse [ProductCardModel]
/// directly — no second product representation (Stage F4 §4).
class FavoriteRepository {
  FavoriteRepository(this._api);

  final ApiClient _api;

  Future<List<ProductCardModel>> list() async {
    final data = await _api.get('/me/favorites');
    final list = (data as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => ProductCardModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// `POST /me/favorites/:productId` → `{ "favorited": true }`.
  Future<void> add(int productId) => _api.post('/me/favorites/$productId');

  /// `DELETE /me/favorites/:productId` → `{ "favorited": false }`.
  Future<void> remove(int productId) => _api.delete('/me/favorites/$productId');
}

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(ref.watch(apiClientProvider));
});
