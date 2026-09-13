import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_view.dart';

/// Shown when a signed-in non-seller (or a seller whose account is
/// inactive) reaches a `/seller/*` route. The backend RBAC is the real
/// boundary — this is the UX side of it (Stage F2 §36).
class SellerForbiddenScreen extends ConsumerWidget {
  const SellerForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: context.nova.bg,
      appBar: AppBar(title: Text(s('nav.seller'))),
      body: EmptyView(
        icon: Icons.lock_outline_rounded,
        title: s('seller.forbidden.title'),
        body: s('seller.forbidden.body'),
        action: FilledButton(
          onPressed: () => context.go(Routes.home),
          child: Text(s('nav.home')),
        ),
      ),
    );
  }
}
