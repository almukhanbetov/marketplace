import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/api_exception.dart';
import '../../dashboard/application/seller_dashboard_controller.dart';
import '../../finance/application/seller_finance_controller.dart';
import '../data/seller_payout_models.dart';
import '../data/seller_payout_repository.dart';
import 'seller_payouts_controller.dart';

enum PayoutRequestPhase { editing, submitting, success, error }

class PayoutRequestState {
  const PayoutRequestState({
    required this.phase,
    required this.idempotencyKey,
    this.result,
    this.error,
  });

  final PayoutRequestPhase phase;

  /// Stable for the whole attempt — reused across submit / transport-retry
  /// / ambiguous-result retry so the backend dedupes to one payout
  /// (Stage F6D §10/§15/§18). A genuinely new attempt gets a new key
  /// (see [PayoutRequestController.startNewAttempt]).
  final String idempotencyKey;
  final CreatePayoutResult? result;
  final Object? error;

  bool get isSubmitting => phase == PayoutRequestPhase.submitting;

  String? get errorCode =>
      error is ApiException ? (error! as ApiException).code : null;

  PayoutRequestState copyWith({
    PayoutRequestPhase? phase,
    String? idempotencyKey,
    CreatePayoutResult? result,
    Object? error,
  }) => PayoutRequestState(
    phase: phase ?? this.phase,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    result: result ?? this.result,
    error: error,
  );
}

/// One payout-request attempt. `autoDispose`: opening the request sheet
/// builds a new controller with a new idempotency key; staying in the
/// sheet and retrying reuses it (§10 — never regenerated on rebuild).
class PayoutRequestController extends Notifier<PayoutRequestState> {
  static const _uuid = Uuid();

  SellerPayoutRepository get _repo => ref.read(sellerPayoutRepositoryProvider);

  @override
  PayoutRequestState build() => PayoutRequestState(
    phase: PayoutRequestPhase.editing,
    idempotencyKey: _uuid.v4(),
  );

  /// Abandon this attempt and start a clean one — new key, cleared state.
  void startNewAttempt() {
    state = PayoutRequestState(
      phase: PayoutRequestPhase.editing,
      idempotencyKey: _uuid.v4(),
    );
  }

  /// `POST /seller/payouts`. Concurrent calls are impossible — the guard
  /// bails while [PayoutRequestState.isSubmitting]. Backend idempotency is
  /// the real protection; this is the extra client latch (§11).
  Future<void> submit(String amount) async {
    if (state.phase == PayoutRequestPhase.submitting) return;

    state = state.copyWith(phase: PayoutRequestPhase.submitting, error: null);
    try {
      final result = await _repo.create(
        amount: amount,
        idempotencyKey: state.idempotencyKey, // SAME key on every retry
      );
      // Refresh everything that shows a balance / payout (§12).
      await ref.read(sellerPayoutsControllerProvider.notifier).refresh();
      await ref.read(sellerFinanceControllerProvider.notifier).refresh();
      ref.invalidate(sellerDashboardControllerProvider);
      if (!ref.mounted) return;
      state = state.copyWith(phase: PayoutRequestPhase.success, result: result);
    } on Object catch (e) {
      // Keep the same idempotency key so a retry after an ambiguous
      // failure can't create a second payout (§15).
      if (!ref.mounted) return;
      state = state.copyWith(phase: PayoutRequestPhase.error, error: e);
    }
  }

  /// Retry after a failure — deliberately keeps the same idempotency key.
  Future<void> retry(String amount) => submit(amount);
}

final payoutRequestControllerProvider =
    NotifierProvider.autoDispose<PayoutRequestController, PayoutRequestState>(
      PayoutRequestController.new,
    );
