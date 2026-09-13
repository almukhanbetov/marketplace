import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_view.dart';

/// Admin has NO mobile UI (Stage F2 §33). An authenticated admin lands
/// here: a clean notice + a logout affordance, nothing else.
class AdminNoticeScreen extends ConsumerWidget {
  const AdminNoticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: context.nova.bg,
      appBar: AppBar(title: Text(s('app.name'))),
      body: EmptyView(
        icon: Icons.desktop_windows_outlined,
        title: s('admin.notice.title'),
        body: s('admin.notice.body'),
        action: OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
            if (context.mounted) context.go(Routes.home);
          },
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: Text(s('profile.action.logout')),
        ),
      ),
    );
  }
}
