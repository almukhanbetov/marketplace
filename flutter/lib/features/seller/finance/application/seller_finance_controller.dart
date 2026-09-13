import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../data/seller_finance_models.dart';
import '../data/seller_finance_repository.dart';

enum SellerFinanceStatus { loading, loaded, error }

class SellerFinanceState {
  const SellerFinanceState({required this.status, this.data, this.error});

  final SellerFinanceStatus status;
  final SellerFinanceModel? data;
  final Object? error;

  bool get isLoading => status == SellerFinanceStatus.loading;

  static const loading = SellerFinanceState(
    status: SellerFinanceStatus.loading,
  );
}

/// `GET /seller/finance`. `autoDispose`; a payout success invalidates this
/// provider so the figures re-read (Stage F6D §12).
class SellerFinanceController extends Notifier<SellerFinanceState> {
  SellerFinanceRepository get _repo =>
      ref.read(sellerFinanceRepositoryProvider);

  @override
  SellerFinanceState build() {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        // Logout: clear the seller data from memory (Stage F6E §13).
        state = SellerFinanceState.loading;
      }
    });
    Future.microtask(load);
    return SellerFinanceState.loading;
  }

  Future<void> load() async {
    state = SellerFinanceState.loading;
    try {
      final data = await _repo.getSummary();
      if (!ref.mounted) return;
      state = SellerFinanceState(
        status: SellerFinanceStatus.loaded,
        data: data,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = SellerFinanceState(status: SellerFinanceStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();
}

final sellerFinanceControllerProvider =
    NotifierProvider.autoDispose<SellerFinanceController, SellerFinanceState>(
      SellerFinanceController.new,
    );
