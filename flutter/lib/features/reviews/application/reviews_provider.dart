import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../data/review_models.dart';
import '../data/review_repository.dart';

enum ReviewsStatus { loading, loadingMore, loaded, error, errorMore }

class ReviewsState {
  const ReviewsState({
    required this.items,
    required this.total,
    required this.status,
    this.error,
  });

  final List<ReviewModel> items;
  final int total;
  final ReviewsStatus status;
  final Object? error;

  bool get isFirstLoad => status == ReviewsStatus.loading && items.isEmpty;
  bool get isEmpty => status == ReviewsStatus.loaded && items.isEmpty;
  bool get hasMore => items.length < total;

  static const initial = ReviewsState(
    items: [],
    total: 0,
    status: ReviewsStatus.loading,
  );

  ReviewsState copyWith({
    List<ReviewModel>? items,
    int? total,
    ReviewsStatus? status,
    Object? error,
  }) => ReviewsState(
    items: items ?? this.items,
    total: total ?? this.total,
    status: status ?? this.status,
    error: error,
  );
}

class ReviewsController extends Notifier<ReviewsState> {
  ReviewsController(this._productId);

  final int _productId;
  int _generation = 0;

  @override
  ReviewsState build() {
    Future.microtask(refresh);
    return ReviewsState.initial;
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    state = ReviewsState.initial;
    try {
      final page = await ref
          .read(reviewRepositoryProvider)
          .getProductReviews(_productId);
      if (gen != _generation) return;
      state = ReviewsState(
        items: page.items,
        total: page.meta.total,
        status: ReviewsStatus.loaded,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(status: ReviewsStatus.error, error: e);
    }
  }

  Future<void> loadMore() async {
    final st = state;
    if (!st.hasMore ||
        st.status == ReviewsStatus.loading ||
        st.status == ReviewsStatus.loadingMore) {
      return;
    }
    final gen = ++_generation;
    state = st.copyWith(status: ReviewsStatus.loadingMore);
    try {
      final page = await ref
          .read(reviewRepositoryProvider)
          .getProductReviews(_productId, offset: st.items.length);
      if (gen != _generation) return;
      final seen = st.items.map((r) => r.id).toSet();
      state = state.copyWith(
        items: [...st.items, ...page.items.where((r) => seen.add(r.id))],
        total: page.meta.total,
        status: ReviewsStatus.loaded,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(status: ReviewsStatus.errorMore, error: e);
    }
  }
}

final reviewsProvider = NotifierProvider.autoDispose
    .family<ReviewsController, ReviewsState, int>(ReviewsController.new);
