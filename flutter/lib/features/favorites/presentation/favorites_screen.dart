import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_skeleton.dart';
import '../../../shared/widgets/product_grid.dart';
import '../application/favorites_controller.dart';

/// DB-backed favourites (`/me/favorites`). Anonymous users are redirected
/// to login by the route guard before they ever reach this screen.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(favoritesControllerProvider);
    final controller = ref.read(favoritesControllerProvider.notifier);

    Widget body;
    if (!auth.isAuthenticated) {
      body = EmptyView(
        icon: Icons.favorite_border_rounded,
        title: s('favorites.loginRequired'),
        action: FilledButton(
          onPressed: () => context.go(
            '${Routes.login}?from=${Uri.encodeComponent(Routes.favorites)}',
          ),
          child: Text(s('action.login')),
        ),
      );
    } else if (state.isFirstLoad || state.status == FavStatus.initial) {
      body = const _FavSkeleton();
    } else if (state.status == FavStatus.error && state.items.isEmpty) {
      body = ErrorView(error: state.error, onRetry: controller.refresh);
    } else if (state.isEmpty) {
      body = EmptyView(
        icon: Icons.favorite_border_rounded,
        title: s('favorites.empty.title'),
        body: s('favorites.empty.body'),
        action: FilledButton(
          onPressed: () => context.go(Routes.catalog),
          child: Text(s('product.toCatalog')),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          slivers: [
            SliverProductGrid(products: state.items),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('nav.favorites'))),
      body: body,
    );
  }
}

class _FavSkeleton extends StatelessWidget {
  const _FavSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.sm,
        NovaSpace.xs,
        NovaSpace.sm,
        NovaSpace.xs,
      ),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: NovaSpace.sm,
        mainAxisSpacing: NovaSpace.sm,
        childAspectRatio: 0.56,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => const NovaSkeleton(radius: NovaRadii.md),
    );
  }
}
