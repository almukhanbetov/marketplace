import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nova_badges.dart';
import '../../../../shared/widgets/nova_section_label.dart';
import '../../../../shared/widgets/nova_skeleton.dart';
import '../../../../shared/widgets/rating_stars.dart';
import '../../shared/presentation/seller_unavailable_view.dart';
import '../application/seller_dashboard_controller.dart';
import '../data/seller_dashboard_models.dart';
import 'widgets/seller_metric_card.dart';
import 'widgets/seller_quick_actions.dart';

/// The real seller dashboard (`GET /seller/dashboard`). Mobile-first metric
/// cards + quick actions — no desktop tables (Stage F6A §9/§12). Access is
/// already gated by the route guard (seller role + active linked account).
class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(sellerDashboardControllerProvider);
    final controller = ref.read(sellerDashboardControllerProvider.notifier);

    Widget body;
    switch (state.status) {
      case SellerDashboardStatus.loading:
        body = const _DashboardSkeleton();
      case SellerDashboardStatus.unavailable:
        body = const SellerUnavailableView();
      case SellerDashboardStatus.error:
        body = ErrorView(error: state.error, onRetry: controller.refresh);
      case SellerDashboardStatus.data:
        body = RefreshIndicator(
          onRefresh: controller.refresh,
          child: _Content(view: state.view!),
        );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.dashboard.title'))),
      body: body,
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.view});
  final SellerDashboardView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final m = view.metrics;

    final cards = <Widget>[
      SellerMetricCard(
        icon: Icons.trending_up_rounded,
        label: s('seller.metric.salesToday'),
        value: Money.format(m.salesToday),
        tone: MetricTone.success,
        emphasize: true,
      ),
      SellerMetricCard(
        icon: Icons.receipt_long_outlined,
        label: s('seller.metric.ordersToday'),
        value: '${m.ordersToday}',
        sub: s(
          'seller.metric.ordersTotal',
        ).replaceFirst('{n}', '${m.ordersTotal}'),
        tone: MetricTone.accent,
        emphasize: true,
      ),
      SellerMetricCard(
        icon: Icons.account_balance_wallet_outlined,
        label: s('seller.metric.availableBalance'),
        value: Money.format(m.availableBalance),
        tone: MetricTone.success,
      ),
      SellerMetricCard(
        icon: Icons.schedule_rounded,
        label: s('seller.metric.pendingBalance'),
        value: Money.format(m.pendingBalance),
        tone: MetricTone.neutral,
      ),
      SellerMetricCard(
        icon: Icons.sell_outlined,
        label: s('seller.metric.activeOffers'),
        value: '${m.activeOffers}',
        tone: MetricTone.neutral,
      ),
      SellerMetricCard(
        icon: Icons.warning_amber_rounded,
        label: s('seller.metric.lowStock'),
        value: '${m.lowStockOffers}',
        sub: m.hasLowStock
            ? s(
                'seller.metric.lowStockHint',
              ).replaceFirst('{n}', '${m.lowStockThreshold}')
            : null,
        tone: m.hasLowStock ? MetricTone.warning : MetricTone.neutral,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.md,
        NovaSpace.sm,
        NovaSpace.md,
        NovaSpace.xl,
      ),
      children: [
        _Header(view: view),
        const Gap(NovaSpace.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 520 ? 3 : 2;
            final w = (constraints.maxWidth - (cols - 1) * NovaSpace.sm) / cols;
            return Wrap(
              spacing: NovaSpace.sm,
              runSpacing: NovaSpace.sm,
              children: [
                for (final card in cards) SizedBox(width: w, child: card),
              ],
            );
          },
        ),
        const Gap(NovaSpace.xl),
        NovaSectionLabel(
          s('seller.dashboard.quickActions'),
          padding: EdgeInsets.zero,
        ),
        const Gap(NovaSpace.sm),
        const SellerQuickActions(),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.view});
  final SellerDashboardView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final name = view.sellerName.isNotEmpty
        ? view.sellerName
        : s('seller.dashboard.title');

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.storefront_rounded, color: c.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                  if (view.isVerified) ...[
                    const SizedBox(width: 6),
                    const VerifiedBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              if (view.metrics.reviewCount > 0)
                RatingStars(
                  rating: view.metrics.rating,
                  reviewCount: view.metrics.reviewCount,
                  size: 12,
                )
              else
                Text(
                  s('seller.dashboard.noReviews'),
                  style: TextStyle(fontSize: 12, color: c.text3),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double h) => NovaSkeleton(height: h);

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(NovaSpace.md),
      children: [
        box(46),
        const Gap(NovaSpace.lg),
        Wrap(
          spacing: NovaSpace.sm,
          runSpacing: NovaSpace.sm,
          children: [
            for (var i = 0; i < 6; i++)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 42) / 2,
                child: box(110),
              ),
          ],
        ),
        const Gap(NovaSpace.xl),
        box(52),
        const Gap(NovaSpace.sm),
        box(52),
      ],
    );
  }
}
