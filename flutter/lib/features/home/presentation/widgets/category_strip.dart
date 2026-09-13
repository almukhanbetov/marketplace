import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../../shared/models/localized_text.dart';

/// Presentation-only icon map by slug — the backend rarely has category
/// artwork, so we key a Material icon off the (stable) slug. Names /
/// existence still come from the API (§13/§84).
IconData categoryIcon(String slug) => switch (slug) {
  'electronics' => Icons.devices_other_rounded,
  'computers' => Icons.laptop_mac_rounded,
  'fashion' => Icons.checkroom_rounded,
  'shoes' => Icons.ice_skating_rounded,
  'beauty' => Icons.spa_rounded,
  'home' => Icons.chair_rounded,
  'auto' => Icons.directions_car_rounded,
  'sport' => Icons.fitness_center_rounded,
  'kids' => Icons.toys_rounded,
  'grocery' => Icons.local_grocery_store_rounded,
  _ => Icons.category_rounded,
};

class CategoryStrip extends ConsumerWidget {
  const CategoryStrip({super.key, required this.categories});

  final List<CategoryModel> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: NovaSpace.md),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: NovaSpace.sm),
        itemBuilder: (context, i) {
          final cat = categories[i];
          return InkWell(
            borderRadius: BorderRadius.circular(NovaRadii.md),
            onTap: () => context.go(
              '${Routes.catalog}?category=${Uri.encodeComponent(cat.slug)}',
            ),
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(NovaRadii.lg),
                    ),
                    child: Icon(
                      categoryIcon(cat.slug),
                      color: c.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: NovaSpace.xs),
                  Text(
                    s.pick(cat.name),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.1,
                      color: c.text2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
