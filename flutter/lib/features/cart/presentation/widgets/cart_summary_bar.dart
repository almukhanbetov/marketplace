import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/nova_sticky_bar.dart';
import '../../data/cart_models.dart';

/// Sticky bottom area: backend subtotal + checkout button. Navigates to the
/// real `/checkout` screen (Stage F5). **No order is created here** — the
/// order is only created by the "Place order" CTA on the checkout screen.
class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({super.key, required this.cart});

  final CartModel cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return NovaStickyBar(
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s('cart.subtotal'),
                style: TextStyle(fontSize: 11.5, color: c.text3),
              ),
              Text(
                Money.format(cart.subtotal),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.price,
                ),
              ),
            ],
          ),
          const SizedBox(width: NovaSpace.md),
          Expanded(
            child: FilledButton(
              onPressed: cart.isEmpty
                  ? null
                  : () => context.push(Routes.checkout),
              child: Text(s('cart.checkout')),
            ),
          ),
        ],
      ),
    );
  }
}
