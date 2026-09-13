import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../shared/models/paginated.dart';
import 'review_models.dart';

const kReviewPageSize = 10;

class ReviewRepository {
  ReviewRepository(this._api);

  final ApiClient _api;

  Future<Paginated<ReviewModel>> getProductReviews(
    int productId, {
    int offset = 0,
    int limit = kReviewPageSize,
  }) async {
    final res = await _api.getList(
      '/products/$productId/reviews',
      query: {'limit': limit, 'offset': offset},
    );
    final list = (res.data as List?) ?? const [];
    return Paginated(
      items: list
          .whereType<Map>()
          .map((m) => ReviewModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      meta: res.meta,
    );
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(apiClientProvider));
});
