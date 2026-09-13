import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../data/seller_public_models.dart';
import '../data/seller_public_repository.dart';

enum PagedStatus { loading, loadingMore, loaded, error, errorMore }

class SellerProductsState {
  const SellerProductsState({
    required this.items,
    required this.total,
    required this.status,
    this.error,
  });

  final List<SellerProductModel> items;
  final int total;
  final PagedStatus status;
  final Object? error;

  bool get isFirstLoad => status == PagedStatus.loading && items.isEmpty;
  bool get isEmpty => status == PagedStatus.loaded && items.isEmpty;
  bool get hasMore => items.length < total;

  static const initial = SellerProductsState(
    items: [],
    total: 0,
    status: PagedStatus.loading,
  );

  SellerProductsState copyWith({
    List<SellerProductModel>? items,
    int? total,
    PagedStatus? status,
    Object? error,
  }) => SellerProductsState(
    items: items ?? this.items,
    total: total ?? this.total,
    status: status ?? this.status,
    error: error,
  );
}

class SellerProductsController extends Notifier<SellerProductsState> {
  SellerProductsController(this._sellerId);

  final int _sellerId;
  int _generation = 0;

  @override
  SellerProductsState build() {
    Future.microtask(refresh);
    return SellerProductsState.initial;
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    state = SellerProductsState.initial;
    try {
      final page = await ref
          .read(sellerPublicRepositoryProvider)
          .getSellerProducts(_sellerId);
      if (gen != _generation) return;
      state = SellerProductsState(
        items: page.items,
        total: page.meta.total,
        status: PagedStatus.loaded,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(status: PagedStatus.error, error: e);
    }
  }

  Future<void> loadMore() async {
    final st = state;
    if (!st.hasMore ||
        st.status == PagedStatus.loading ||
        st.status == PagedStatus.loadingMore) {
      return;
    }
    final gen = ++_generation;
    state = st.copyWith(status: PagedStatus.loadingMore);
    try {
      final page = await ref
          .read(sellerPublicRepositoryProvider)
          .getSellerProducts(_sellerId, offset: st.items.length);
      if (gen != _generation) return;
      final seen = st.items.map((p) => p.productId).toSet();
      state = state.copyWith(
        items: [...st.items, ...page.items.where((p) => seen.add(p.productId))],
        total: page.meta.total,
        status: PagedStatus.loaded,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(status: PagedStatus.errorMore, error: e);
    }
  }
}

final sellerProductsProvider = NotifierProvider.autoDispose
    .family<SellerProductsController, SellerProductsState, int>(
      SellerProductsController.new,
    );
