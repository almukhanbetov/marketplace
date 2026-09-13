import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../shared/models/paginated.dart';
import 'seller_offer_models.dart';

/// `/seller/offers` (Stage 7). The seller id always comes from the
/// authenticated caller — no id in any URL or body (Stage F6B §9). The
/// backend owns validation, SKU-uniqueness and the public-catalog
/// visibility of an offer (§13).
class SellerOffersRepository {
  SellerOffersRepository(this._api);

  final ApiClient _api;

  Future<Paginated<SellerOfferModel>> list({
    String search = '',
    SellerOfferFilter filter = SellerOfferFilter.all,
    bool lowStockOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _api.getList(
      '/seller/offers',
      query: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (filter.wire != null) 'status': filter.wire,
        if (lowStockOnly) 'low_stock': 'true',
        'limit': limit,
        'offset': offset,
      },
    );
    final list = (res.data as List?) ?? const [];
    return Paginated(
      items: list
          .whereType<Map>()
          .map((m) => SellerOfferModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      meta: res.meta,
    );
  }

  /// `POST /seller/offers` → `{ id }`.
  Future<int> create(NewOfferInput input) async {
    final data = await _api.post('/seller/offers', body: input.toJson());
    return (Map<String, dynamic>.from(data as Map)['id'] as num).toInt();
  }

  /// `PUT /seller/offers/:offerId`.
  Future<void> update(int offerId, EditOfferInput input) =>
      _api.put('/seller/offers/$offerId', body: input.toJson());

  /// `PATCH /seller/offers/:offerId/status`.
  Future<void> setActive(int offerId, {required bool active}) =>
      _api.patch('/seller/offers/$offerId/status', body: {'is_active': active});
}

final sellerOffersRepositoryProvider = Provider<SellerOffersRepository>((ref) {
  return SellerOffersRepository(ref.watch(apiClientProvider));
});
