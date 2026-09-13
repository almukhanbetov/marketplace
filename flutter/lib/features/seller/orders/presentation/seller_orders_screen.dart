import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nova_skeleton.dart';
import '../application/seller_orders_controller.dart';
import 'widgets/seller_order_card.dart';

/// `GET /seller/orders` — read-only history of orders touching this
/// seller's lines (Stage F6C §3). Mobile cards, infinite scroll,
/// pull-to-refresh. No status-changing action anywhere (§16).
class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
        ref.read(sellerOrdersControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(sellerOrdersControllerProvider);
    final controller = ref.read(sellerOrdersControllerProvider.notifier);

    Widget body;
    if (state.isFirstLoad) {
      body = const _OrdersSkeleton();
    } else if (state.status == SellerOrdersStatus.error &&
        state.items.isEmpty) {
      body = ErrorView(error: state.error, onRetry: controller.refresh);
    } else if (state.isEmpty) {
      body = EmptyView(
        icon: Icons.list_alt_outlined,
        title: s('seller.orders.empty.title'),
        body: s('seller.orders.empty.body'),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount:
              state.items.length +
              (state.status == SellerOrdersStatus.loadingMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final o = state.items[i];
            return SellerOrderCard(
              order: o,
              onTap: () => context.push(Routes.sellerOrder(o.orderId)),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.orders.title'))),
      body: body,
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) => const NovaSkeletonList(itemHeight: 120);
}
