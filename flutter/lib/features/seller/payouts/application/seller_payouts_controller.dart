import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../data/seller_payout_models.dart';
import '../data/seller_payout_repository.dart';

enum SellerPayoutsStatus { loading, loaded, error }

class SellerPayoutsState {
  const SellerPayoutsState({
    required this.status,
    this.items = const [],
    this.error,
  });

  final SellerPayoutsStatus status;
  final List<SellerPayoutModel> items;
  final Object? error;

  bool get isFirstLoad =>
      status == SellerPayoutsStatus.loading && items.isEmpty;
  bool get isEmpty => status == SellerPayoutsStatus.loaded && items.isEmpty;

  static const loading = SellerPayoutsState(
    status: SellerPayoutsStatus.loading,
  );

  SellerPayoutsState copyWith({
    SellerPayoutsStatus? status,
    List<SellerPayoutModel>? items,
    Object? error,
  }) => SellerPayoutsState(
    status: status ?? this.status,
    items: items ?? this.items,
    error: error,
  );
}

/// `GET /seller/payouts` — read side. A successful request invalidates
/// this so the new payout appears immediately (Stage F6D §12).
class SellerPayoutsController extends Notifier<SellerPayoutsState> {
  SellerPayoutRepository get _repo => ref.read(sellerPayoutRepositoryProvider);

  @override
  SellerPayoutsState build() {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        // Logout: clear the seller data from memory (Stage F6E §13).
        state = SellerPayoutsState.loading;
      }
    });
    Future.microtask(load);
    return SellerPayoutsState.loading;
  }

  Future<void> load() async {
    state = state.copyWith(status: SellerPayoutsStatus.loading);
    try {
      final items = await _repo.list();
      if (!ref.mounted) return;
      state = SellerPayoutsState(
        status: SellerPayoutsStatus.loaded,
        items: items,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: SellerPayoutsStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();
}

final sellerPayoutsControllerProvider =
    NotifierProvider.autoDispose<SellerPayoutsController, SellerPayoutsState>(
      SellerPayoutsController.new,
    );
