import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// Shared chrome for the login and register screens: NOVA wordmark, a
/// title + subtitle, and a keyboard-safe scrolling body so fields never
/// overflow when the keyboard opens (Stage F2 §78).
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nova;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(backgroundColor: c.bg, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'N',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        s('app.name'),
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpace.xl),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: NovaSpace.xs),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: c.text2),
                  ),
                  const SizedBox(height: NovaSpace.xl),
                  ...children,
                  if (footer != null) ...[
                    const SizedBox(height: NovaSpace.xs),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner for a failed submit (network / server / rate limit
/// / a field-less backend error).
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Container(
      margin: const EdgeInsets.only(bottom: NovaSpace.md),
      padding: const EdgeInsets.symmetric(
        horizontal: NovaSpace.sm,
        vertical: NovaSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(NovaRadii.sm),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: c.danger),
          const SizedBox(width: NovaSpace.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: c.danger, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
