import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'cart_models.dart';

/// `/me/cart`. Every mutation returns the full refreshed cart, so the
/// controller never has to reconcile — it replaces state with the
/// response (§13/§19).
class CartRepository {
  CartRepository(this._api);

  final ApiClient _api;

  Future<CartModel> getCart() => _unwrap(_api.get('/me/cart'));

  /// Only `seller_offer_id` + `quantity` — the backend is the sole price
  /// authority (§14). Same offer id ⇒ backend increments the line (§19).
  Future<CartModel> addItem(int sellerOfferId, int quantity) => _unwrap(
    _api.post(
      '/me/cart/items',
      body: {'seller_offer_id': sellerOfferId, 'quantity': quantity},
    ),
  );

  Future<CartModel> updateQuantity(int itemId, int quantity) => _unwrap(
    _api.patch('/me/cart/items/$itemId', body: {'quantity': quantity}),
  );

  Future<CartModel> removeItem(int itemId) =>
      _unwrap(_api.delete('/me/cart/items/$itemId'));

  Future<CartModel> clear() => _unwrap(_api.delete('/me/cart'));

  Future<CartModel> _unwrap(Future<dynamic> call) async {
    final data = await call;
    return CartModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});
