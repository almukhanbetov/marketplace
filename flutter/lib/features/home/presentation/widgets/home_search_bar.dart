import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';

/// A tap target that looks like a search field but navigates to the
/// catalog with the field focused (§11 — real results only, no local
/// search on the home screen).
class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return Semantics(
      button: true,
      label: s('home.searchHint'),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('${Routes.catalog}?focus=1'),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: c.text3),
              const SizedBox(width: 8),
              Text(
                s('home.searchHint'),
                style: TextStyle(color: c.text3, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
