import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';

enum OrdersStatus { initial, loading, loaded, error, loggedOut }

class OrdersState {
  const OrdersState({required this.status, this.items = const [], this.error});

  final OrdersStatus status;
  final List<OrderListItemModel> items;
  final Object? error;

  bool get isFirstLoad => status == OrdersStatus.loading && items.isEmpty;
  bool get isEmpty => status == OrdersStatus.loaded && items.isEmpty;

  static const initial = OrdersState(status: OrdersStatus.initial);
  static const loggedOut = OrdersState(status: OrdersStatus.loggedOut);

  OrdersState copyWith({
    OrdersStatus? status,
    List<OrderListItemModel>? items,
    Object? error,
  }) => OrdersState(
    status: status ?? this.status,
    items: items ?? this.items,
    error: error,
  );
}

/// DB-backed order history (`GET /me/orders`). No local order store — the
/// list always comes from Postgres, so a new order shows up after any app
/// restart / session restore (§45/§46). Cleared in memory on logout.
class OrdersController extends Notifier<OrdersState> {
  OrderRepository get _repo => ref.read(orderRepositoryProvider);

  @override
  OrdersState build() {
    ref.listen(authControllerProvider, (prev, next) {
      final was = prev?.status;
      if (next.status == AuthStatus.authenticated &&
          was != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        state = OrdersState.loggedOut;
      }
    });
    if (ref.read(authControllerProvider).isAuthenticated) {
      Future.microtask(load);
    }
    return OrdersState.initial;
  }

  Future<void> load() async {
    state = state.copyWith(status: OrdersStatus.loading);
    try {
      final items = await _repo.getOrders();
      if (!ref.mounted) return;
      state = OrdersState(status: OrdersStatus.loaded, items: items);
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: OrdersStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();
}

final ordersControllerProvider =
    NotifierProvider<OrdersController, OrdersState>(OrdersController.new);

/// One order's full detail. `autoDispose` so leaving the screen frees it;
/// Riverpod-3 auto-retry is disabled app-wide, so a failure stays a
/// failure until the user retries (which re-reads this provider).
final orderDetailProvider = FutureProvider.autoDispose
    .family<OrderDetailModel, int>((ref, orderId) {
      return ref.watch(orderRepositoryProvider).getOrder(orderId);
    });
