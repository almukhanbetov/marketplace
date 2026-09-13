import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/router/routes.dart';
import '../../../../../core/theme/app_colors.dart';

/// The five seller-console entry points (Stage F6A §10). In F6A they open
/// placeholders; F6B fills them in.
class SellerQuickActions extends ConsumerWidget {
  const SellerQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);

    const actions = <_Action>[
      _Action('seller.action.offers', Icons.sell_outlined, Routes.sellerOffers),
      _Action(
        'seller.action.inventory',
        Icons.inventory_2_outlined,
        Routes.sellerInventory,
      ),
      _Action(
        'seller.action.orders',
        Icons.list_alt_outlined,
        Routes.sellerOrders,
      ),
      _Action(
        'seller.action.finance',
        Icons.payments_outlined,
        Routes.sellerFinance,
      ),
      _Action(
        'seller.action.payouts',
        Icons.account_balance_outlined,
        Routes.sellerPayouts,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 520 ? 3 : 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in actions)
              SizedBox(
                width: (constraints.maxWidth - (cols - 1) * 10) / cols,
                child: _ActionCard(
                  label: s(a.labelKey),
                  icon: a.icon,
                  onTap: () => context.go(a.route),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Action {
  const _Action(this.labelKey, this.icon, this.route);
  final String labelKey;
  final IconData icon;
  final String route;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: c.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}
