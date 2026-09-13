import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/errors/api_exception.dart';
import '../../data/seller_public_repository.dart';
import '../data/seller_dashboard_models.dart';
import '../data/seller_dashboard_repository.dart';

enum SellerDashboardStatus {
  loading,
  data,
  error,

  /// The seller account is gone or deactivated (403 from `/seller/*`) — the
  /// screen must show a safe "seller area unavailable" state and let the
  /// user leave (Stage F6A §16).
  unavailable,
}

class SellerDashboardState {
  const SellerDashboardState({required this.status, this.view, this.error});

  final SellerDashboardStatus status;
  final SellerDashboardView? view;
  final Object? error;

  bool get isLoading => status == SellerDashboardStatus.loading;

  static const loading = SellerDashboardState(
    status: SellerDashboardStatus.loading,
  );
}

/// Drives the real seller dashboard. `autoDispose` — leaving the seller
/// area frees it, re-entering refetches. Metrics come from
/// `/seller/dashboard`; the store name / verified flag are a best-effort
/// read of the public `/sellers/:id` profile (id taken from the auth
/// context, never the UI — §2).
class SellerDashboardController extends Notifier<SellerDashboardState> {
  SellerDashboardRepository get _repo =>
      ref.read(sellerDashboardRepositoryProvider);

  @override
  SellerDashboardState build() {
    // Normally the screen only mounts after the route guard has resolved
    // auth, so a seller is present. But if the provider is instantiated
    // while the session is still restoring, reload once auth lands.
    ref.listen(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        load();
      } else if (next.status == AuthStatus.unauthenticated) {
        // Logout: drop the seller data from memory (Stage F6E §13); it
        // reloads from the backend on the next login.
        state = SellerDashboardState.loading;
      }
    });
    Future.microtask(load);
    return SellerDashboardState.loading;
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    state = SellerDashboardState.loading;

    final sellerId = ref.read(authControllerProvider).user?.sellerId;
    if (sellerId == null) {
      state = const SellerDashboardState(
        status: SellerDashboardStatus.unavailable,
      );
      return;
    }

    try {
      final metrics = await _repo.getDashboard();
      if (!ref.mounted) return;

      // Best-effort identity — a failure here must not fail the dashboard.
      var name = '';
      var verified = false;
      var identityLoaded = false;
      try {
        final profile = await ref
            .read(sellerPublicRepositoryProvider)
            .getSeller(sellerId);
        name = profile.name;
        verified = profile.isVerified;
        identityLoaded = true;
      } on Object {
        // keep the fallback (empty name, no badge)
      }
      if (!ref.mounted) return;

      state = SellerDashboardState(
        status: SellerDashboardStatus.data,
        view: SellerDashboardView(
          metrics: metrics,
          sellerName: name,
          isVerified: verified,
          identityLoaded: identityLoaded,
        ),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      if (e.kind == ApiErrorKind.forbidden) {
        state = const SellerDashboardState(
          status: SellerDashboardStatus.unavailable,
        );
      } else {
        state = SellerDashboardState(
          status: SellerDashboardStatus.error,
          error: e,
        );
      }
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = SellerDashboardState(
        status: SellerDashboardStatus.error,
        error: e,
      );
    }
  }

  Future<void> refresh() => load();
}

final sellerDashboardControllerProvider =
    NotifierProvider.autoDispose<
      SellerDashboardController,
      SellerDashboardState
    >(SellerDashboardController.new);
