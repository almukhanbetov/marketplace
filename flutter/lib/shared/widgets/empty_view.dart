import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import 'state_views.dart';

/// Neutral "there's nothing here" state — never a blank screen
/// (Stage F1 §36). Structure and copy are unchanged from F1; F7A moved
/// the layout into the shared [NovaStateView] so empty / error / loading
/// all look like one family (§33).
class EmptyView extends ConsumerWidget {
  const EmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.body,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String? title;
  final String? body;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return NovaStateView(
      icon: icon,
      title: title ?? s('state.empty.title'),
      message: body ?? s('state.empty.body'),
      action: action,
      compact: compact,
    );
  }
}
