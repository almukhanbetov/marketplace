import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/models/localized_text.dart';
import '../../../../shared/widgets/nova_feedback.dart';
import '../../../../shared/widgets/nova_network_image.dart';
import '../../../../shared/widgets/price_row.dart';
import '../../application/cart_controller.dart';
import '../../data/cart_models.dart';

class CartItemTile extends ConsumerWidget {
  const CartItemTile({super.key, required this.item});

  final CartItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final controller = ref.read(cartControllerProvider.notifier);
    final busy = ref.watch(
      cartControllerProvider.select(
        (st) => st.mutatingItemIds.contains(item.id),
      ),
    );

    Future<void> guard(Future<void> Function() action) async {
      try {
        await action();
      } on ApiException catch (e) {
        if (context.mounted) NovaSnackbar.error(context, s.apiError(e.code));
      }
    }

    Future<void> confirmRemove() async {
      final ok = await novaConfirm(
        context,
        title: s('cart.removeConfirmTitle'),
        message: s('cart.removeConfirmBody'),
        confirmLabel: s('action.delete'),
        cancelLabel: s('action.cancel'),
        destructive: true,
      );
      if (ok) await guard(() => controller.remove(item.id));
    }

    final unavailable = !item.isAvailable;

    return Opacity(
      opacity: unavailable ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.push(Routes.product(item.product.id)),
              child: SizedBox(
                width: 68,
                height: 68,
                child: NovaNetworkImage(
                  url: item.product.primaryImage,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.pick(item.product.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  PriceRow(
                    price: item.price,
                    oldPrice: item.oldPrice,
                    priceSize: 13.5,
                    oldSize: 11,
                  ),
                  if (unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s('error.OFFER_UNAVAILABLE'),
                        style: TextStyle(fontSize: 11.5, color: c.danger),
                      ),
                    )
                  else if (item.atStockLimit)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s(
                          'cart.qtyLimit',
                        ).replaceFirst('{n}', '${item.availableQuantity}'),
                        style: TextStyle(fontSize: 11.5, color: c.warning),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QtyStepper(
                        quantity: item.quantity,
                        busy: busy,
                        canIncrement:
                            !unavailable &&
                            item.quantity < item.availableQuantity,
                        onMinus: () {
                          if (item.quantity <= 1) {
                            confirmRemove();
                          } else {
                            guard(
                              () => controller.setQuantity(
                                item.id,
                                item.quantity - 1,
                              ),
                            );
                          }
                        },
                        onPlus: () => guard(
                          () => controller.setQuantity(
                            item.id,
                            item.quantity + 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Money.format(item.lineTotal),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: c.price,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: busy ? null : confirmRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: s('action.delete'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.busy,
    required this.canIncrement,
    required this.onMinus,
    required this.onPlus,
  });

  final int quantity;
  final bool busy;
  final bool canIncrement;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    Widget btn(IconData icon, VoidCallback? onTap, String semantic) =>
        Semantics(
          button: true,
          label: semantic,
          child: InkResponse(
            onTap: busy ? null : onTap,
            radius: 22,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                size: 18,
                color: onTap == null ? c.text3 : c.text,
              ),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(NovaRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove_rounded, onMinus, 'minus'),
          SizedBox(
            width: 26,
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    ),
                  )
                : Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
          ),
          btn(Icons.add_rounded, canIncrement ? onPlus : null, 'plus'),
        ],
      ),
    );
  }
}
