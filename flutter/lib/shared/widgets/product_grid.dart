import 'package:flutter/material.dart';

import '../../features/catalog/data/catalog_models.dart';
import 'product_card.dart';

/// Responsive 2-column (phone) / 3–4-column (tablet) product grid as a
/// sliver. Card height is intrinsic (`mainAxisExtent`-free) so longer
/// RU/KAZ names never overflow — the grid measures each child.
class SliverProductGrid extends StatelessWidget {
  const SliverProductGrid({
    super.key,
    required this.products,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
  });

  final List<ProductCardModel> products;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1000
        ? 4
        : width >= 720
        ? 3
        : 2;

    return SliverPadding(
      padding: padding,
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          // Taller than wide: image (1:1) + ~130px of text block. Tuned so
          // two lines of product name + meta never overflow at 360px.
          childAspectRatio: 0.56,
        ),
        itemCount: products.length,
        itemBuilder: (context, i) => ProductCard(product: products[i]),
      ),
    );
  }
}
