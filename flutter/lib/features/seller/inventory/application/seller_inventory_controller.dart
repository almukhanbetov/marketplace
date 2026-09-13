import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../../dashboard/application/seller_dashboard_controller.dart';
import '../data/seller_inventory_models.dart';
import '../data/seller_inventory_repository.dart';

enum SellerInventoryStatus { loading, loaded, error }

class SellerInventoryState {
  const SellerInventoryState({
    required this.status,
    this.items = const [],
    this.mutating = const {},
    this.error,
  });

  final SellerInventoryStatus status;
  final List<SellerInventoryItemModel> items;

  /// Offer ids being PATCHed right now — per-row spinner only (§15).
  final Set<int> mutating;
  final Object? error;

  bool get isFirstLoad =>
      status == SellerInventoryStatus.loading && items.isEmpty;
  bool get isEmpty => status == SellerInventoryStatus.loaded && items.isEmpty;
  int get lowStockCount => items.where((i) => i.isLowStock).length;

  static const initial = SellerInventoryState(
    status: SellerInventoryStatus.loading,
  );

  SellerInventoryState copyWith({
    SellerInventoryStatus? status,
    List<SellerInventoryItemModel>? items,
    Set<int>? mutating,
    Object? error,
  }) => SellerInventoryState(
    status: status ?? this.status,
    items: items ?? this.items,
    mutating: mutating ?? this.mutating,
    error: error,
  );
}

/// `GET/PATCH /seller/inventory`. Every quantity change is followed by a
/// fresh list read (the backend recomputes `is_low_stock`) and invalidates
/// the dashboard so its low-stock metric catches up (§17).
class SellerInventoryController extends Notifier<SellerInventoryState> {
  SellerInventoryRepository get _repo =>
      ref.read(sellerInventoryRepositoryProvider);

  @override
  SellerInventoryState build() {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        // Logout: clear the seller data from memory (Stage F6E §13).
        state = SellerInventoryState.initial;
      }
    });
    Future.microtask(load);
    return SellerInventoryState.initial;
  }

  Future<void> load() async {
    state = state.copyWith(status: SellerInventoryStatus.loading);
    try {
      final items = await _repo.list();
      if (!ref.mounted) return;
      state = SellerInventoryState(
        status: SellerInventoryStatus.loaded,
        items: items,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: SellerInventoryStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();

  /// Rethrows on failure so the edit sheet can show the localized error.
  Future<void> updateQuantity(int offerId, int availableQuantity) async {
    if (state.mutating.contains(offerId)) return;
    state = state.copyWith(mutating: {...state.mutating, offerId});
    try {
      await _repo.updateQuantity(offerId, availableQuantity);
      await refresh();
      ref.invalidate(sellerDashboardControllerProvider);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(mutating: {...state.mutating}..remove(offerId));
      }
    }
  }
}

final sellerInventoryControllerProvider =
    NotifierProvider.autoDispose<
      SellerInventoryController,
      SellerInventoryState
    >(SellerInventoryController.new);
