import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import 'seller_dashboard_models.dart';

/// `GET /api/v1/seller/dashboard`. The seller identity comes entirely from
/// the authenticated caller's active seller account — there is no seller id
/// in this URL and the app never sends one (Stage F6A §2/§6). A deactivated
/// seller gets a 403 here (`ApiErrorKind.forbidden`), surfaced as an
/// [ApiException] for the controller to turn into the "seller unavailable"
/// state.
class SellerDashboardRepository {
  SellerDashboardRepository(this._api);

  final ApiClient _api;

  Future<SellerDashboardModel> getDashboard() async {
    final data = await _api.get('/seller/dashboard');
    return SellerDashboardModel.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }
}

final sellerDashboardRepositoryProvider = Provider<SellerDashboardRepository>((
  ref,
) {
  return SellerDashboardRepository(ref.watch(apiClientProvider));
});
