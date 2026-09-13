import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/models/localized_text.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nova_feedback.dart';
import '../../../../shared/widgets/nova_skeleton.dart';
import '../application/seller_inventory_controller.dart';
import '../data/seller_inventory_models.dart';
import 'widgets/inventory_edit_sheet.dart';

/// `GET /seller/inventory` — mobile rows with per-row edit (Stage F6B
/// §14/§15). Low-stock uses the backend flag only (§16).
class SellerInventoryScreen extends ConsumerWidget {
  const SellerInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final state = ref.watch(sellerInventoryControllerProvider);
    final controller = ref.read(sellerInventoryControllerProvider.notifier);

    Widget body;
    if (state.isFirstLoad) {
      body = const _InventorySkeleton();
    } else if (state.status == SellerInventoryStatus.error &&
        state.items.isEmpty) {
      body = ErrorView(error: state.error, onRetry: controller.refresh);
    } else if (state.isEmpty) {
      body = EmptyView(
        icon: Icons.inventory_2_outlined,
        title: s('seller.inventory.empty.title'),
        body: s('seller.inventory.empty.body'),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: state.items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) return _LowStockBanner(count: state.lowStockCount);
            return _InventoryRow(item: state.items[i - 1]);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.inventory.title'))),
      body: body,
    );
  }
}

class _LowStockBanner extends ConsumerWidget {
  const _LowStockBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (count == 0) return const SizedBox.shrink();
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s(
                'seller.inventory.lowStockBanner',
              ).replaceFirst('{n}', '$count'),
              style: TextStyle(
                fontSize: 12.5,
                color: c.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryRow extends ConsumerWidget {
  const _InventoryRow({required this.item});
  final SellerInventoryItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final busy = ref.watch(
      sellerInventoryControllerProvider.select(
        (st) => st.mutating.contains(item.offerId),
      ),
    );

    Future<void> edit() async {
      final newQty = await showInventoryEditSheet(context, item);
      if (newQty == null) return;
      try {
        await ref
            .read(sellerInventoryControllerProvider.notifier)
            .updateQuantity(item.offerId, newQty);
      } on ApiException catch (e) {
        if (context.mounted) NovaSnackbar.error(context, s.apiError(e.code));
      }
    }

    return Container(
      padding: const EdgeInsets.all(NovaSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(NovaRadii.md),
        border: Border.all(
          color: item.isLowStock ? c.warning.withValues(alpha: 0.5) : c.border,
        ),
        boxShadow: NovaShadows.card(Theme.of(context).brightness),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.pick(item.productName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU: ${item.sku}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.text3),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    Text(
                      s(
                        'seller.inventory.availableN',
                      ).replaceFirst('{n}', '${item.availableQuantity}'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: item.isLowStock ? c.warning : c.text,
                      ),
                    ),
                    Text(
                      s(
                        'seller.inventory.reservedN',
                      ).replaceFirst('{n}', '${item.reservedQuantity}'),
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                    if (item.isLowStock)
                      Text(
                        s('seller.inventory.lowStock'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.warning,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              onPressed: edit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: s('seller.inventory.edit'),
            ),
        ],
      ),
    );
  }
}

class _InventorySkeleton extends StatelessWidget {
  const _InventorySkeleton();

  @override
  Widget build(BuildContext context) =>
      const NovaSkeletonList(count: 6, itemHeight: 78);
}
