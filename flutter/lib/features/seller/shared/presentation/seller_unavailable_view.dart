import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../shared/widgets/empty_view.dart';

/// Shown inside a seller screen when `/seller/*` answers 403 — the linked
/// seller account is missing or was deactivated mid-session. Lets the user
/// leave the seller area safely (Stage F6A §16). The route guard also
/// bounces `/seller/*` once `/auth/me` refreshes and drops the seller link.
class SellerUnavailableView extends ConsumerWidget {
  const SellerUnavailableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return EmptyView(
      icon: Icons.storefront_outlined,
      title: s('seller.unavailable.title'),
      body: s('seller.unavailable.body'),
      action: FilledButton(
        onPressed: () => context.go(Routes.home),
        child: Text(s('nav.home')),
      ),
    );
  }
}
