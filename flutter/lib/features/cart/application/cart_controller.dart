import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../data/cart_models.dart';
import '../data/cart_repository.dart';

enum CartStatus { initial, loading, loaded, error, loggedOut }

class CartState {
  const CartState({
    required this.status,
    this.cart = CartModel.empty,
    this.mutatingItemIds = const {},
    this.adding = false,
    this.error,
  });

  final CartStatus status;
  final CartModel cart;

  /// Cart-item ids with an in-flight qty/remove request — their controls
  /// disable individually, the rest of the cart stays interactive (§23).
  final Set<int> mutatingItemIds;
  final bool adding;
  final Object? error;

  int get itemCount => cart.itemCount;
  bool get isFirstLoad => status == CartStatus.loading && cart.isEmpty;
  bool get isEmpty => status == CartStatus.loaded && cart.isEmpty;

  static const initial = CartState(status: CartStatus.initial);
  static const loggedOut = CartState(status: CartStatus.loggedOut);

  CartState copyWith({
    CartStatus? status,
    CartModel? cart,
    Set<int>? mutatingItemIds,
    bool? adding,
    Object? error,
  }) => CartState(
    status: status ?? this.status,
    cart: cart ?? this.cart,
    mutatingItemIds: mutatingItemIds ?? this.mutatingItemIds,
    adding: adding ?? this.adding,
    error: error,
  );
}

/// DB-backed cart. **Backend-confirmed** mutations (not optimistic, §59):
/// every call returns the full cart and we replace state with it. Cleared
/// in memory on logout, reloaded on login; the DB cart is untouched.
class CartController extends Notifier<CartState> {
  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  CartState build() {
    ref.listen(authControllerProvider, (prev, next) {
      final was = prev?.status;
      if (next.status == AuthStatus.authenticated &&
          was != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        state = CartState.loggedOut;
      }
    });
    if (ref.read(authControllerProvider).isAuthenticated) {
      Future.microtask(load);
    }
    return CartState.initial;
  }

  Future<void> load() async {
    state = state.copyWith(status: CartStatus.loading);
    try {
      state = CartState(status: CartStatus.loaded, cart: await _repo.getCart());
    } on Object catch (e) {
      state = state.copyWith(status: CartStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();

  /// Add a selected seller offer. Rethrows so the caller can localize the
  /// INSUFFICIENT_STOCK / OFFER_UNAVAILABLE toast (§24/§62).
  Future<void> addOffer(int sellerOfferId, {int quantity = 1}) async {
    state = state.copyWith(adding: true, error: null);
    try {
      final cart = await _repo.addItem(sellerOfferId, quantity);
      state = CartState(status: CartStatus.loaded, cart: cart);
    } on Object catch (e) {
      state = state.copyWith(adding: false, error: e);
      rethrow;
    }
  }

  Future<void> setQuantity(int itemId, int quantity) async {
    if (quantity < 1 || state.mutatingItemIds.contains(itemId)) return;
    state = state.copyWith(mutatingItemIds: {...state.mutatingItemIds, itemId});
    try {
      final cart = await _repo.updateQuantity(itemId, quantity);
      state = CartState(status: CartStatus.loaded, cart: cart);
    } on Object catch (e) {
      state = state.copyWith(
        mutatingItemIds: {...state.mutatingItemIds}..remove(itemId),
        error: e,
      );
      rethrow;
    }
  }

  Future<void> remove(int itemId) async {
    if (state.mutatingItemIds.contains(itemId)) return;
    state = state.copyWith(mutatingItemIds: {...state.mutatingItemIds, itemId});
    try {
      final cart = await _repo.removeItem(itemId);
      state = CartState(status: CartStatus.loaded, cart: cart);
    } on Object catch (e) {
      state = state.copyWith(
        mutatingItemIds: {...state.mutatingItemIds}..remove(itemId),
        error: e,
      );
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      state = CartState(status: CartStatus.loaded, cart: await _repo.clear());
    } on Object catch (e) {
      state = state.copyWith(error: e);
      rethrow;
    }
  }

  void clearLocal() => state = CartState.loggedOut;
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

/// Badge count for the bottom-nav cart icon — real DB state only (§29).
final cartBadgeCountProvider = Provider<int>((ref) {
  return ref.watch(cartControllerProvider.select((s) => s.cart.itemCount));
});
