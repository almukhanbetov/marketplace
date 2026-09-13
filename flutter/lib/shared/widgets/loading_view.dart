import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Full-area loading state — used only where the screen structure isn't
/// known ahead of time; screens with a known shape use a skeleton instead
/// (§35).
class LoadingView extends ConsumerWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const Gap(NovaSpace.sm),
          Text(
            message ?? s('state.loading'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.text2),
          ),
        ],
      ),
    );
  }
}
