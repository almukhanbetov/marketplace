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
import '../application/orders_controller.dart';
import 'widgets/order_card.dart';

/// `GET /me/orders` — DB-backed history, newest first. Anonymous users are
/// redirected to login by the route guard (§74).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(ordersControllerProvider);
    final controller = ref.read(ordersControllerProvider.notifier);

    Widget body;
    if (!auth.isAuthenticated) {
      body = EmptyView(
        icon: Icons.receipt_long_outlined,
        title: s('auth.loginRequired.title'),
        action: FilledButton(
          onPressed: () => context.go(
            '${Routes.login}?from=${Uri.encodeComponent(Routes.orders)}',
          ),
          child: Text(s('action.login')),
        ),
      );
    } else if (state.isFirstLoad || state.status == OrdersStatus.initial) {
      body = const _OrdersSkeleton();
    } else if (state.status == OrdersStatus.error && state.items.isEmpty) {
      body = ErrorView(error: state.error, onRetry: controller.refresh);
    } else if (state.isEmpty) {
      body = EmptyView(
        icon: Icons.receipt_long_outlined,
        title: s('orders.empty.title'),
        body: s('orders.empty.body'),
        action: FilledButton(
          onPressed: () => context.go(Routes.catalog),
          child: Text(s('product.toCatalog')),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            NovaSpace.md,
            NovaSpace.sm,
            NovaSpace.md,
            NovaSpace.xl,
          ),
          itemCount: state.items.length,
          itemBuilder: (context, i) => OrderCard(
            order: state.items[i],
            onTap: () => context.push(Routes.order(state.items[i].id)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('orders.title'))),
      body: body,
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) => const NovaSkeletonList(itemHeight: 104);
}
