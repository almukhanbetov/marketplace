import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_feedback.dart';
import '../../../shared/widgets/nova_skeleton.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../application/cart_controller.dart';
import 'widgets/cart_item_tile.dart';
import 'widgets/cart_summary_bar.dart';

/// DB-backed cart (`/me/cart`), grouped by seller (§20). Anonymous users
/// are redirected to login by the route guard.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);

    final canClear = state.status == CartStatus.loaded && !state.cart.isEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(s('cart.title')),
        actions: [
          if (canClear)
            TextButton(
              onPressed: () => _confirmClear(context, s, controller),
              child: Text(s('cart.clear')),
            ),
        ],
      ),
      bottomNavigationBar:
          (state.status == CartStatus.loaded && !state.cart.isEmpty)
          ? CartSummaryBar(cart: state.cart)
          : null,
      body: _body(context, ref, s, auth, state, controller),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppStrings s,
    AuthState auth,
    CartState state,
    CartController controller,
  ) {
    if (!auth.isAuthenticated) {
      return EmptyView(
        icon: Icons.shopping_bag_outlined,
        title: s('auth.loginRequired.title'),
        action: FilledButton(
          onPressed: () => context.go(
            '${Routes.login}?from=${Uri.encodeComponent(Routes.cart)}',
          ),
          child: Text(s('action.login')),
        ),
      );
    }
    if (state.isFirstLoad || state.status == CartStatus.initial) {
      return const _CartSkeleton();
    }
    if (state.status == CartStatus.error && state.cart.isEmpty) {
      return ErrorView(error: state.error, onRetry: controller.refresh);
    }
    if (state.isEmpty) {
      return EmptyView(
        icon: Icons.shopping_bag_outlined,
        title: s('cart.empty.title'),
        body: s('cart.empty.body'),
        action: FilledButton(
          onPressed: () => context.go(Routes.catalog),
          child: Text(s('product.toCatalog')),
        ),
      );
    }

    final groups = state.cart.groupedBySeller;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          NovaSpace.sm,
          NovaSpace.sm,
          NovaSpace.sm,
          NovaSpace.sm,
        ),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const Gap(NovaSpace.sm),
        itemBuilder: (context, gi) {
          final g = groups[gi];
          return DecoratedBox(
            decoration: BoxDecoration(
              color: context.nova.surface,
              borderRadius: BorderRadius.circular(NovaRadii.md),
              border: Border.all(color: context.nova.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SellerHeader(
                  name: g.seller.name,
                  rating: g.seller.rating,
                  sellerId: g.seller.id,
                ),
                for (var i = 0; i < g.items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 92, color: context.nova.border),
                  CartItemTile(item: g.items[i]),
                ],
                const Gap(NovaSpace.xs),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppStrings s,
    CartController controller,
  ) async {
    final ok = await novaConfirm(
      context,
      title: s('cart.clear.confirmTitle'),
      message: s('cart.clear.confirmBody'),
      confirmLabel: s('cart.clear'),
      cancelLabel: s('action.cancel'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await controller.clear();
    } on ApiException catch (e) {
      if (context.mounted) NovaSnackbar.error(context, s.apiError(e.code));
    }
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({
    required this.name,
    required this.rating,
    required this.sellerId,
  });

  final String name;
  final double rating;
  final int sellerId;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return InkWell(
      onTap: () => context.push(Routes.seller(sellerId)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, size: 16, color: c.text2),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
            const Spacer(),
            RatingStars(rating: rating, showCount: false, size: 11),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _CartSkeleton extends StatelessWidget {
  const _CartSkeleton();

  @override
  Widget build(BuildContext context) =>
      const NovaSkeletonList(count: 3, itemHeight: 88);
}
