import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Every feature screen in Stage F1 renders one of these. It proves the
/// route exists, the shell wraps it, theming + localization resolve, and
/// navigation reaches it — without pretending a feature is built.
///
/// Stages F2–F6 replace these bodies one feature at a time.
class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({
    super.key,
    required this.titleKey,
    required this.icon,
    this.stage,
    this.showAppBar = true,
  });

  final String titleKey;
  final IconData icon;
  final String? stage;
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: c.accent),
            ),
            const SizedBox(height: 18),
            Text(
              s(titleKey),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.surface2,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                stage == null
                    ? s('screen.placeholder.badge')
                    : '${s('screen.placeholder.badge')} · $stage',
                style: TextStyle(fontSize: 12, color: c.text2),
              ),
            ),
          ],
        ),
      ),
    );

    if (!showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(s(titleKey))),
      body: body,
    );
  }
}
