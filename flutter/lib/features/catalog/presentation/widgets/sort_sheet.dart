import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/product_query.dart';

/// Compact sort picker. Returns the chosen [ProductSort] (or null if
/// dismissed).
Future<ProductSort?> showSortSheet(
  BuildContext context, {
  required ProductSort current,
}) {
  return showModalBottomSheet<ProductSort>(
    context: context,
    showDragHandle: true,
    builder: (context) => _SortSheet(current: current),
  );
}

class _SortSheet extends ConsumerWidget {
  const _SortSheet({required this.current});
  final ProductSort current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              s('sort.title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          for (final sort in ProductSort.values)
            ListTile(
              title: Text(s(sort.labelKey)),
              trailing: sort == current
                  ? Icon(Icons.check_rounded, color: c.accent)
                  : null,
              onTap: () => Navigator.pop(context, sort),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
