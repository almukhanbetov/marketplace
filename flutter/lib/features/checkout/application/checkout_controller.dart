import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/api_exception.dart';
import '../../addresses/application/addresses_controller.dart';
import '../../cart/application/cart_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../../orders/data/order_models.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/data/payment_method.dart';

enum CheckoutPhase { editing, submitting, success, error }

class CheckoutState {
  const CheckoutState({
    required this.phase,
    required this.idempotencyKey,
    this.selectedAddressId,
    this.payment = PaymentMethod.card,
    this.result,
    this.error,
  });

  final CheckoutPhase phase;

  /// Stable for the whole checkout attempt: the same key is reused across
  /// submit / transport-retry / ambiguous-result retry so the backend
  /// dedupes to one order (§16/§17/§31/§32). A genuinely new attempt gets a
  /// new key — see [CheckoutController.startNewAttempt].
  final String idempotencyKey;

  final int? selectedAddressId;
  final PaymentMethod payment;
  final CreateOrderResult? result;
  final Object? error;

  bool get isSubmitting => phase == CheckoutPhase.submitting;
  bool get canSubmit =>
      selectedAddressId != null && phase != CheckoutPhase.submitting;

  String? get errorCode =>
      error is ApiException ? (error as ApiException).code : null;

  CheckoutState copyWith({
    CheckoutPhase? phase,
    String? idempotencyKey,
    int? selectedAddressId,
    PaymentMethod? payment,
    CreateOrderResult? result,
    Object? error,
  }) => CheckoutState(
    phase: phase ?? this.phase,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    selectedAddressId: selectedAddressId ?? this.selectedAddressId,
    payment: payment ?? this.payment,
    result: result ?? this.result,
    error: error,
  );
}

/// Drives one checkout attempt. `autoDispose`: opening `/checkout` fresh
/// builds a new controller with a new idempotency key; staying on the
/// screen and retrying reuses it.
class CheckoutController extends Notifier<CheckoutState> {
  static const _uuid = Uuid();

  OrderRepository get _orders => ref.read(orderRepositoryProvider);

  @override
  CheckoutState build() =>
      CheckoutState(phase: CheckoutPhase.editing, idempotencyKey: _uuid.v4());

  /// Pick the default address once, when the list first arrives, without
  /// clobbering a choice the user already made.
  void selectAddressIfUnset(int? addressId) {
    if (state.selectedAddressId == null && addressId != null) {
      state = state.copyWith(selectedAddressId: addressId);
    }
  }

  void selectAddress(int addressId) =>
      state = state.copyWith(selectedAddressId: addressId, error: null);

  void selectPayment(PaymentMethod method) =>
      state = state.copyWith(payment: method, error: null);

  /// Abandon this attempt and start a clean one — new idempotency key,
  /// cleared error/result. Used when the user explicitly restarts checkout.
  void startNewAttempt() {
    state = CheckoutState(
      phase: CheckoutPhase.editing,
      idempotencyKey: _uuid.v4(),
      selectedAddressId: state.selectedAddressId,
      payment: state.payment,
    );
  }

  /// `POST /me/orders`. Concurrent calls are impossible — the guard bails
  /// while [CheckoutState.isSubmitting]. Backend idempotency is the real
  /// protection; this is the extra client latch (§18).
  Future<void> submit() async {
    if (state.phase == CheckoutPhase.submitting) return;
    final addressId = state.selectedAddressId;
    if (addressId == null) return;

    state = state.copyWith(phase: CheckoutPhase.submitting, error: null);
    try {
      final result = await _orders.createOrder(
        addressId: addressId,
        payment: state.payment,
        idempotencyKey: state.idempotencyKey, // SAME key on every retry
      );
      // Backend already cleared the cart transactionally — just re-read it
      // (never a redundant DELETE, §21) and refresh the history list.
      await ref.read(cartControllerProvider.notifier).refresh();
      await ref.read(ordersControllerProvider.notifier).refresh();
      if (!ref.mounted) return;
      state = state.copyWith(phase: CheckoutPhase.success, result: result);
    } on ApiException catch (e) {
      // Stock / offer / address drift → pull fresh state so the user sees
      // reality when they go back (§28/§29/§30). Never clear the cart here.
      switch (e.code) {
        case 'INSUFFICIENT_STOCK':
        case 'OFFER_UNAVAILABLE':
        case 'SELLER_OFFER_NOT_FOUND':
        case 'CART_EMPTY':
          await ref.read(cartControllerProvider.notifier).refresh();
        case 'ADDRESS_NOT_FOUND':
          await ref.read(addressesControllerProvider.notifier).refresh();
      }
      if (!ref.mounted) return;
      state = state.copyWith(phase: CheckoutPhase.error, error: e);
    } on Object catch (e) {
      // Transport failure (offline / timeout / ambiguous). Keep the same
      // idempotency key so a retry can't double-order (§31/§32).
      if (!ref.mounted) return;
      state = state.copyWith(phase: CheckoutPhase.error, error: e);
    }
  }

  /// Retry after a failure — deliberately keeps the same idempotency key.
  Future<void> retry() => submit();
}

final checkoutControllerProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
      CheckoutController.new,
    );
