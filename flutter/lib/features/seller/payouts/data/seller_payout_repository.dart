import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import 'seller_payout_models.dart';

/// `/seller/payouts` (Stage 7 §21). A payout draws **only** from
/// `available_amount`; the backend returns `409
/// INSUFFICIENT_AVAILABLE_BALANCE` otherwise. Requests are idempotent on
/// `(seller_id, Idempotency-Key)` — a repeated key returns the same payout,
/// so a transport retry can never create a second one (§10/§15/§18).
class SellerPayoutRepository {
  SellerPayoutRepository(this._api);

  final ApiClient _api;

  /// `GET /seller/payouts` — a plain array, newest first.
  Future<List<SellerPayoutModel>> list() async {
    final data = await _api.get('/seller/payouts');
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((m) => SellerPayoutModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// `POST /seller/payouts` — body `{amount}`, key in the `Idempotency-Key`
  /// header. Never sends any bank / account / card field (§14).
  Future<CreatePayoutResult> create({
    required String amount,
    required String idempotencyKey,
  }) async {
    final data = await _api.post(
      '/seller/payouts',
      body: {'amount': amount},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return CreatePayoutResult(
      SellerPayoutModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}

final sellerPayoutRepositoryProvider = Provider<SellerPayoutRepository>((ref) {
  return SellerPayoutRepository(ref.watch(apiClientProvider));
});
