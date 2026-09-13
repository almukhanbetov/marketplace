import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../data/address_models.dart';
import '../data/address_repository.dart';

enum AddressesStatus { initial, loading, loaded, error, loggedOut }

class AddressesState {
  const AddressesState({
    required this.status,
    this.items = const [],
    this.mutating = false,
    this.error,
  });

  final AddressesStatus status;
  final List<AddressModel> items;
  final bool mutating;
  final Object? error;

  bool get isFirstLoad => status == AddressesStatus.loading && items.isEmpty;
  bool get isEmpty => status == AddressesStatus.loaded && items.isEmpty;
  AddressModel? get defaultAddress {
    for (final a in items) {
      if (a.isDefault) return a;
    }
    return null;
  }

  static const initial = AddressesState(status: AddressesStatus.initial);
  static const loggedOut = AddressesState(status: AddressesStatus.loggedOut);

  AddressesState copyWith({
    AddressesStatus? status,
    List<AddressModel>? items,
    bool? mutating,
    Object? error,
  }) => AddressesState(
    status: status ?? this.status,
    items: items ?? this.items,
    mutating: mutating ?? this.mutating,
    error: error,
  );
}

/// DB-backed addresses. All mutations are **backend-confirmed** (§59); a
/// set-default reloads the list so the single-default invariant always
/// comes from Postgres, never client bookkeeping (§40).
class AddressesController extends Notifier<AddressesState> {
  AddressRepository get _repo => ref.read(addressRepositoryProvider);

  @override
  AddressesState build() {
    ref.listen(authControllerProvider, (prev, next) {
      final was = prev?.status;
      if (next.status == AuthStatus.authenticated &&
          was != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        state = AddressesState.loggedOut;
      }
    });
    if (ref.read(authControllerProvider).isAuthenticated) {
      Future.microtask(load);
    }
    return AddressesState.initial;
  }

  Future<void> load() async {
    state = state.copyWith(status: AddressesStatus.loading);
    try {
      state = AddressesState(
        status: AddressesStatus.loaded,
        items: await _repo.list(),
      );
    } on Object catch (e) {
      state = state.copyWith(status: AddressesStatus.error, error: e);
    }
  }

  Future<void> refresh() => load();

  Future<void> create(AddressInput input) => _mutate(() => _repo.create(input));

  Future<void> update(int id, AddressInput input) =>
      _mutate(() => _repo.update(id, input));

  Future<void> delete(int id) => _mutate(() => _repo.delete(id));

  Future<void> setDefault(int id) => _mutate(() => _repo.setDefault(id));

  Future<void> _mutate(Future<void> Function() call) async {
    state = state.copyWith(mutating: true, error: null);
    try {
      await call();
      final items = await _repo.list(); // re-read → authoritative
      state = AddressesState(status: AddressesStatus.loaded, items: items);
    } on Object catch (e) {
      state = state.copyWith(mutating: false, error: e);
      rethrow;
    }
  }

  void clearLocal() => state = AddressesState.loggedOut;
}

final addressesControllerProvider =
    NotifierProvider<AddressesController, AddressesState>(
      AddressesController.new,
    );
