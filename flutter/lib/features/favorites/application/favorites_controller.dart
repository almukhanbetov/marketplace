import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../catalog/data/catalog_models.dart';
import '../data/favorite_repository.dart';

enum FavStatus { initial, loading, loaded, error, loggedOut }

class FavoritesState {
  const FavoritesState({
    required this.status,
    this.items = const [],
    this.ids = const {},
    this.pending = const {},
    this.error,
  });

  final FavStatus status;
  final List<ProductCardModel> items;
  final Set<int> ids;

  /// Product ids with an in-flight toggle — used to debounce rapid taps
  /// (Stage F4 §7).
  final Set<int> pending;
  final Object? error;

  bool get isFirstLoad => status == FavStatus.loading && items.isEmpty;
  bool get isEmpty => status == FavStatus.loaded && items.isEmpty;

  static const initial = FavoritesState(status: FavStatus.initial);
  static const loggedOut = FavoritesState(status: FavStatus.loggedOut);

  FavoritesState copyWith({
    FavStatus? status,
    List<ProductCardModel>? items,
    Set<int>? ids,
    Set<int>? pending,
    Object? error,
  }) => FavoritesState(
    status: status ?? this.status,
    items: items ?? this.items,
    ids: ids ?? this.ids,
    pending: pending ?? this.pending,
    error: error,
  );
}

/// DB-backed favourites. Optimistic on toggle (§7/§59), with rollback on
/// failure. Cleared in memory on logout, reloaded on login — the backend
/// row is never touched by an auth transition (§31/§81).
class FavoritesController extends Notifier<FavoritesState> {
  FavoriteRepository get _repo => ref.read(favoriteRepositoryProvider);

  @override
  FavoritesState build() {
    ref.listen(authControllerProvider, (prev, next) {
      final was = prev?.status;
      if (next.status == AuthStatus.authenticated &&
          was != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        state = FavoritesState.loggedOut;
      }
    });

    if (ref.read(authControllerProvider).isAuthenticated) {
      Future.microtask(load);
    }
    return FavoritesState.initial;
  }

  Future<void> load() async {
    state = state.copyWith(status: FavStatus.loading);
    try {
      final items = await _repo.list();
      state = FavoritesState(
        status: FavStatus.loaded,
        items: items,
        ids: items.map((p) => p.id).toSet(),
      );
    } on Object catch (e) {
      state = state.copyWith(status: FavStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();

  /// Toggle from anywhere. Pass [known] (the card model) when toggling
  /// from a product card so the favourites list stays in sync without a
  /// refetch.
  Future<void> toggle(int productId, {ProductCardModel? known}) async {
    if (state.pending.contains(productId)) return;
    final wasFav = state.ids.contains(productId);

    // ---- optimistic ----
    final newIds = {...state.ids};
    final newItems = [...state.items];
    if (wasFav) {
      newIds.remove(productId);
      newItems.removeWhere((p) => p.id == productId);
    } else {
      newIds.add(productId);
      if (known != null && newItems.every((p) => p.id != productId)) {
        newItems.insert(0, known);
      }
    }
    state = state.copyWith(
      ids: newIds,
      items: newItems,
      pending: {...state.pending, productId},
      status:
          state.status == FavStatus.initial ||
              state.status == FavStatus.loggedOut
          ? FavStatus.loaded
          : state.status,
    );

    try {
      if (wasFav) {
        await _repo.remove(productId);
      } else {
        await _repo.add(productId);
      }
      state = state.copyWith(pending: {...state.pending}..remove(productId));
    } on Object catch (e) {
      // ---- rollback ----
      final rbIds = {...state.ids};
      final rbItems = [...state.items];
      if (wasFav) {
        rbIds.add(productId);
        if (known != null && rbItems.every((p) => p.id != productId)) {
          rbItems.insert(0, known);
        }
      } else {
        rbIds.remove(productId);
        rbItems.removeWhere((p) => p.id == productId);
      }
      state = state.copyWith(
        ids: rbIds,
        items: rbItems,
        pending: {...state.pending}..remove(productId),
        error: e,
      );
      rethrow; // let the caller show a localized toast
    }
  }

  void clearLocal() => state = FavoritesState.loggedOut;
}

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, FavoritesState>(
      FavoritesController.new,
    );

/// Fine-grained per-product favourite flag — a card only rebuilds when
/// *its* id's membership changes, not on every favourites mutation.
final isFavoriteProvider = Provider.autoDispose.family<bool, int>((ref, id) {
  return ref.watch(
    favoritesControllerProvider.select((s) => s.ids.contains(id)),
  );
});
