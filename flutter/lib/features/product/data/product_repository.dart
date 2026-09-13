import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'product_models.dart';

class ProductRepository {
  ProductRepository(this._api);

  final ApiClient _api;

  /// `GET /products/:id`. A 404 surfaces as an [ApiException] with
  /// `kind == notFound` — the screen renders a not-found state.
  Future<ProductDetailModel> getProduct(int id) async {
    final data = await _api.get('/products/$id');
    return ProductDetailModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `GET /products/:id/offers` — every purchasable seller offer, in the
  /// backend's order (price asc, then seller rating). Not re-sorted here.
  Future<List<SellerOfferModel>> getOffers(int id) async {
    final data = await _api.get('/products/$id/offers');
    final list = (data as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => SellerOfferModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(apiClientProvider));
});

/// Detail + offers are per-id and short-lived — auto-dispose when the
/// screen is popped.
final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetailModel, int>((ref, id) {
      return ref.watch(productRepositoryProvider).getProduct(id);
    });

final productOffersProvider = FutureProvider.autoDispose
    .family<List<SellerOfferModel>, int>((ref, id) {
      return ref.watch(productRepositoryProvider).getOffers(id);
    });
