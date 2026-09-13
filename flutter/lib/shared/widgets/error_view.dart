import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'state_views.dart';

/// Error state with a Retry affordance (Stage F1 §36). Accepts either a
/// plain message or an [ApiException] (whose [ApiException.code] maps to
/// friendly localized copy — never a raw technical string, §34).
class ErrorView extends ConsumerWidget {
  const ErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    final text =
        message ??
        (error is ApiException
            ? s.apiError((error as ApiException).code)
            : s('state.error.body'));

    return NovaStateView(
      icon: Icons.error_outline_rounded,
      iconColor: c.danger,
      iconBackground: c.dangerSoft,
      title: s('state.error.title'),
      message: text,
      compact: compact,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(s('action.retry')),
            ),
    );
  }
}
