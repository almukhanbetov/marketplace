import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import 'seller_inventory_models.dart';

/// `/seller/inventory` (Stage 7). Seller id from the auth context only.
class SellerInventoryRepository {
  SellerInventoryRepository(this._api);

  final ApiClient _api;

  /// `GET /seller/inventory` — a plain array, no pagination in the contract.
  Future<List<SellerInventoryItemModel>> list() async {
    final data = await _api.get('/seller/inventory');
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map(
          (m) =>
              SellerInventoryItemModel.fromJson(Map<String, dynamic>.from(m)),
        )
        .toList();
  }

  /// `PATCH /seller/inventory/:offerId`.
  Future<void> updateQuantity(int offerId, int availableQuantity) => _api.patch(
    '/seller/inventory/$offerId',
    body: {'available_quantity': availableQuantity},
  );
}

final sellerInventoryRepositoryProvider = Provider<SellerInventoryRepository>((
  ref,
) {
  return SellerInventoryRepository(ref.watch(apiClientProvider));
});
