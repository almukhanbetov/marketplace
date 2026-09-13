import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../data/seller_order_models.dart';
import '../data/seller_orders_repository.dart';

enum SellerOrdersStatus { loading, loadingMore, loaded, error, errorMore }

class SellerOrdersState {
  const SellerOrdersState({
    required this.status,
    this.items = const [],
    this.total = 0,
    this.error,
  });

  final SellerOrdersStatus status;
  final List<SellerOrderListItem> items;
  final int total;
  final Object? error;

  bool get isFirstLoad => status == SellerOrdersStatus.loading && items.isEmpty;
  bool get isEmpty => status == SellerOrdersStatus.loaded && items.isEmpty;
  bool get hasMore => items.length < total;

  static const initial = SellerOrdersState(status: SellerOrdersStatus.loading);

  SellerOrdersState copyWith({
    SellerOrdersStatus? status,
    List<SellerOrderListItem>? items,
    int? total,
    Object? error,
  }) => SellerOrdersState(
    status: status ?? this.status,
    items: items ?? this.items,
    total: total ?? this.total,
    error: error,
  );
}

/// `GET /seller/orders` — read-only history of orders touching this
/// seller's lines. No mutation methods exist (§16). `autoDispose`; reloads
/// once auth resolves if the provider was built during session restore.
class SellerOrdersController extends Notifier<SellerOrdersState> {
  SellerOrdersRepository get _repo => ref.read(sellerOrdersRepositoryProvider);
  int _generation = 0;

  @override
  SellerOrdersState build() {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        // Logout: clear the seller data from memory (Stage F6E §13).
        _generation++;
        state = SellerOrdersState.initial;
      }
    });
    Future.microtask(load);
    return SellerOrdersState.initial;
  }

  Future<void> load() async {
    final gen = ++_generation;
    state = state.copyWith(status: SellerOrdersStatus.loading);
    try {
      final page = await _repo.list();
      if (gen != _generation || !ref.mounted) return;
      state = state.copyWith(
        status: SellerOrdersStatus.loaded,
        items: page.items,
        total: page.meta.total,
      );
    } on Object catch (e) {
      if (gen != _generation || !ref.mounted) return;
      state = state.copyWith(status: SellerOrdersStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    final st = state;
    if (!st.hasMore ||
        st.status == SellerOrdersStatus.loading ||
        st.status == SellerOrdersStatus.loadingMore) {
      return;
    }
    final gen = ++_generation;
    state = st.copyWith(status: SellerOrdersStatus.loadingMore);
    try {
      final page = await _repo.list(offset: st.items.length);
      if (gen != _generation || !ref.mounted) return;
      final seen = st.items.map((o) => o.orderId).toSet();
      state = state.copyWith(
        status: SellerOrdersStatus.loaded,
        items: [...st.items, ...page.items.where((o) => seen.add(o.orderId))],
        total: page.meta.total,
      );
    } on Object catch (e) {
      if (gen != _generation || !ref.mounted) return;
      state = state.copyWith(status: SellerOrdersStatus.errorMore, error: e);
    }
  }
}

final sellerOrdersControllerProvider =
    NotifierProvider.autoDispose<SellerOrdersController, SellerOrdersState>(
      SellerOrdersController.new,
    );

/// One seller order's full (seller-scoped) detail. `autoDispose` family.
final sellerOrderDetailProvider = FutureProvider.autoDispose
    .family<SellerOrderDetail, int>((ref, orderId) {
      return ref.watch(sellerOrdersRepositoryProvider).getOrder(orderId);
    });
