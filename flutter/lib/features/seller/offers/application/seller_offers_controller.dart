import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../../dashboard/application/seller_dashboard_controller.dart';
import '../../inventory/application/seller_inventory_controller.dart';
import '../data/seller_offer_models.dart';
import '../data/seller_offers_repository.dart';

enum SellerOffersStatus { loading, loadingMore, loaded, error, errorMore }

class SellerOffersState {
  const SellerOffersState({
    required this.status,
    this.items = const [],
    this.total = 0,
    this.search = '',
    this.filter = SellerOfferFilter.all,
    this.lowStockOnly = false,
    this.mutating = const {},
    this.error,
  });

  final SellerOffersStatus status;
  final List<SellerOfferModel> items;
  final int total;
  final String search;
  final SellerOfferFilter filter;
  final bool lowStockOnly;

  /// Offer ids with an in-flight status toggle — their card shows a spinner
  /// while the rest of the list stays interactive.
  final Set<int> mutating;
  final Object? error;

  bool get isFirstLoad => status == SellerOffersStatus.loading && items.isEmpty;
  bool get isEmpty => status == SellerOffersStatus.loaded && items.isEmpty;
  bool get hasFilters =>
      search.trim().isNotEmpty ||
      filter != SellerOfferFilter.all ||
      lowStockOnly;
  bool get hasMore => items.length < total;

  static const initial = SellerOffersState(status: SellerOffersStatus.loading);

  SellerOffersState copyWith({
    SellerOffersStatus? status,
    List<SellerOfferModel>? items,
    int? total,
    String? search,
    SellerOfferFilter? filter,
    bool? lowStockOnly,
    Set<int>? mutating,
    Object? error,
  }) => SellerOffersState(
    status: status ?? this.status,
    items: items ?? this.items,
    total: total ?? this.total,
    search: search ?? this.search,
    filter: filter ?? this.filter,
    lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    mutating: mutating ?? this.mutating,
    error: error,
  );
}

/// `GET/POST/PUT/PATCH /seller/offers`. Backend-confirmed: every mutation
/// is followed by a fresh list read so the card state (incl. the public
/// low-stock / active flags the backend computes) is authoritative. Create
/// and status changes also invalidate the dashboard + inventory so their
/// metrics catch up (Stage F6B §17).
class SellerOffersController extends Notifier<SellerOffersState> {
  SellerOffersRepository get _repo => ref.read(sellerOffersRepositoryProvider);
  int _generation = 0;

  @override
  SellerOffersState build() {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        // Logout: clear the seller data from memory (Stage F6E §13).
        _generation++;
        state = SellerOffersState.initial;
      }
    });
    Future.microtask(load);
    return SellerOffersState.initial;
  }

  Future<void> load() async {
    final gen = ++_generation;
    state = state.copyWith(status: SellerOffersStatus.loading);
    try {
      final page = await _repo.list(
        search: state.search,
        filter: state.filter,
        lowStockOnly: state.lowStockOnly,
      );
      if (gen != _generation || !ref.mounted) return;
      state = state.copyWith(
        status: SellerOffersStatus.loaded,
        items: page.items,
        total: page.meta.total,
      );
    } on Object catch (e) {
      if (gen != _generation || !ref.mounted) return;
      state = state.copyWith(status: SellerOffersStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    final st = state;
    if (!st.hasMore ||
        st.status == SellerOffersStatus.loading ||
        st.status == SellerOffersStatus.loadingMore) {
      return;
    }
    final gen = ++_generation;
    state = st.copyWith(status: SellerOffersStatus.loadingMore);
    try {
      final page = await _repo.list(
        search: st.search,
        filter: st.filter,
        lowStockOnly: st.lowStockOnly,
        offset: st.items.length,
      );
      if (gen != _generation || !ref.mounted) return;
      final seen = st.items.map((o) => o.id).toSet();
      state = state.copyWith(
        status: SellerOffersStatus.loaded,
        items: [...st.items, ...page.items.where((o) => seen.add(o.id))],
        total: page.meta.total,
      );
    } on Object catch (e) {
      if (gen != _generation || !ref.mounted) return;
      state = state.copyWith(status: SellerOffersStatus.errorMore, error: e);
    }
  }

  void applyQuery({
    String? search,
    SellerOfferFilter? filter,
    bool? lowStockOnly,
  }) {
    state = state.copyWith(
      search: search ?? state.search,
      filter: filter ?? state.filter,
      lowStockOnly: lowStockOnly ?? state.lowStockOnly,
    );
    load();
  }

  /// POST a new offer, then refresh + invalidate the dashboard/inventory.
  /// Rethrows so the form can show the localized `ApiException.code` copy.
  Future<int> createOffer(NewOfferInput input) async {
    final id = await _repo.create(input);
    await refresh();
    _invalidateSiblings();
    return id;
  }

  Future<void> editOffer(int offerId, EditOfferInput input) async {
    await _repo.update(offerId, input);
    await refresh();
  }

  Future<void> setActive(int offerId, {required bool active}) async {
    if (state.mutating.contains(offerId)) return;
    state = state.copyWith(mutating: {...state.mutating, offerId});
    try {
      await _repo.setActive(offerId, active: active);
      await refresh();
      _invalidateSiblings();
    } finally {
      if (ref.mounted) {
        state = state.copyWith(mutating: {...state.mutating}..remove(offerId));
      }
    }
  }

  void _invalidateSiblings() {
    ref.invalidate(sellerDashboardControllerProvider);
    ref.invalidate(sellerInventoryControllerProvider);
  }
}

final sellerOffersControllerProvider =
    NotifierProvider.autoDispose<SellerOffersController, SellerOffersState>(
      SellerOffersController.new,
    );
