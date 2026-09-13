import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../shared/models/paginated.dart';
import 'seller_order_models.dart';

/// `/seller/orders` (Stage 7 §16/§17) — **read-only**. There is no
/// status-mutation endpoint and this repository exposes none. The seller
/// id comes entirely from the authenticated caller; the backend scopes
/// every row and every line to that seller (Stage F6C §5).
class SellerOrdersRepository {
  SellerOrdersRepository(this._api);

  final ApiClient _api;

  Future<Paginated<SellerOrderListItem>> list({
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _api.getList(
      '/seller/orders',
      query: {'limit': limit, 'offset': offset},
    );
    final list = (res.data as List?) ?? const [];
    return Paginated(
      items: list
          .whereType<Map>()
          .map(
            (m) => SellerOrderListItem.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList(),
      meta: res.meta,
    );
  }

  /// `GET /seller/orders/:orderId`. A non-owned or line-less order is
  /// `404 ORDER_NOT_FOUND` server-side — surfaced as an [ApiException].
  Future<SellerOrderDetail> getOrder(int orderId) async {
    final data = await _api.get('/seller/orders/$orderId');
    return SellerOrderDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final sellerOrdersRepositoryProvider = Provider<SellerOrdersRepository>((ref) {
  return SellerOrdersRepository(ref.watch(apiClientProvider));
});
