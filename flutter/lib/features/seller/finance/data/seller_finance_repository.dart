import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import 'seller_finance_models.dart';

/// `GET /api/v1/seller/finance` — read-only. Seller id from the auth
/// context only (Stage F6D §2/§4).
class SellerFinanceRepository {
  SellerFinanceRepository(this._api);

  final ApiClient _api;

  Future<SellerFinanceModel> getSummary() async {
    final data = await _api.get('/seller/finance');
    return SellerFinanceModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final sellerFinanceRepositoryProvider = Provider<SellerFinanceRepository>((
  ref,
) {
  return SellerFinanceRepository(ref.watch(apiClientProvider));
});
