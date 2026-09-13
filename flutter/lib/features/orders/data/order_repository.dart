import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'order_models.dart';
import 'payment_method.dart';

/// `/me/orders` (Stage 6/9). The backend owns the entire order transaction
/// — prices, totals, commissions, inventory, cart-clear. This client sends
/// **only** the two user choices plus the idempotency key (§2/§19/§51).
class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  /// `POST /me/orders`. Body: `{address_id, payment_provider}`. The
  /// idempotency key travels as the `Idempotency-Key` header — the backend
  /// returns the *same* order for a repeated key, so a transport retry with
  /// the same key can never create a second order (§16/§31/§53).
  Future<CreateOrderResult> createOrder({
    required int addressId,
    required PaymentMethod payment,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      '/me/orders',
      body: {'address_id': addressId, 'payment_provider': payment.wire},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return CreateOrderResult(
      OrderDetailModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  /// `GET /me/orders` — full history, newest first (no pagination in the
  /// Stage 6 contract, so none is sent — §35).
  Future<List<OrderListItemModel>> getOrders() async {
    final data = await _api.get('/me/orders');
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((m) => OrderListItemModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// `GET /me/orders/:orderId`. A non-owned or missing id is `404
  /// ORDER_NOT_FOUND` server-side (§64) — surfaced as an [ApiException].
  Future<OrderDetailModel> getOrder(int orderId) async {
    final data = await _api.get('/me/orders/$orderId');
    return OrderDetailModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider));
});
