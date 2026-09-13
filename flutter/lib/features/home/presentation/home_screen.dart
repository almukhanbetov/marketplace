import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_skeleton.dart';
import '../application/home_provider.dart';
import 'widgets/category_strip.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/product_rail.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final async = ref.watch(homeDataProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(homeDataProvider.future),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _TopBar(s: s)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: HomeSearchBar(),
                ),
              ),
              ...async.when(
                loading: () => [
                  const SliverFillRemaining(child: _HomeSkeleton()),
                ],
                error: (e, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(homeDataProvider),
                    ),
                  ),
                ],
                data: (data) => _content(context, ref, s, data),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    AppStrings s,
    HomeData data,
  ) {
    return [
      const SliverToBoxAdapter(child: _PromoBanner()),
      if (data.categories.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              NovaSpace.md,
              NovaSpace.lg,
              NovaSpace.md,
              NovaSpace.sm,
            ),
            child: Text(
              s('home.categories'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        SliverToBoxAdapter(child: CategoryStrip(categories: data.categories)),
      ],
      for (final section in data.rails)
        SliverToBoxAdapter(
          child: ProductRail(
            section: section,
            onRetry: () => ref.invalidate(homeDataProvider),
          ),
        ),
    ];
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nova;
    final auth = ref.watch(authControllerProvider);
    final name = auth.user?.fullName.split(' ').first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Text(
              'N',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'NOVA',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 0.5,
              color: c.text,
            ),
          ),
          const Spacer(),
          if (name != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${s('home.greeting')} $name',
                style: TextStyle(color: c.text2, fontSize: 12.5),
              ),
            ),
          IconButton(
            onPressed: () => context.go(Routes.profile),
            icon: Icon(
              auth.isAuthenticated
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
              color: c.text2,
            ),
            tooltip: s('nav.profile'),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends ConsumerWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.md,
        NovaSpace.xs,
        NovaSpace.md,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(NovaSpace.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: c.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(NovaRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s('home.promo.title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.3,
              ),
            ),
            const Gap(NovaSpace.xs),
            Text(
              s('home.promo.subtitle'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double h, {double? w}) =>
        NovaSkeleton(height: h, width: w, radius: NovaRadii.md);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.md,
        NovaSpace.xs,
        NovaSpace.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(120),
          const Gap(NovaSpace.md),
          box(16, w: 140),
          const Gap(NovaSpace.sm),
          box(90),
          const Gap(NovaSpace.md),
          box(16, w: 120),
          const Gap(NovaSpace.sm),
          Row(
            children: [
              Expanded(child: box(220)),
              const Gap.h(NovaSpace.sm),
              Expanded(child: box(220)),
            ],
          ),
        ],
      ),
    );
  }
}
