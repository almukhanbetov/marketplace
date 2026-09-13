import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../application/home_provider.dart';

/// One horizontal product rail. A failed section shows an inline retry;
/// an empty section renders nothing (§9/§10).
class ProductRail extends ConsumerWidget {
  const ProductRail({super.key, required this.section, required this.onRetry});

  final HomeSection section;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    if (section.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: s(section.titleKey)),
        if (section.failed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  s('home.sectionUnavailable'),
                  style: TextStyle(color: c.text3, fontSize: 12.5),
                ),
                const Spacer(),
                TextButton(onPressed: onRetry, child: Text(s('action.retry'))),
              ],
            ),
          )
        else
          Builder(
            builder: (context) {
              // The rail is a fixed-height horizontal list, so the card's
              // text block would clip the price once the OS font scale
              // grows. Grow the rail (and card) with it (Stage F7B —
              // verified on device at font size 1.3).
              final ts = MediaQuery.textScalerOf(
                context,
              ).scale(1.0).clamp(1.0, 1.4);
              final grow = (ts - 1.0) * 150;
              return SizedBox(
                height: 262 + grow,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: NovaSpace.md),
                  itemCount: section.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: NovaSpace.sm),
                  itemBuilder: (context, i) => ProductCard(
                    product: section.items[i],
                    width: 152 + (ts - 1.0) * 40,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
