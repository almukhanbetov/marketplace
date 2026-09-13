import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/money.dart';
import '../data/order_models.dart';
import 'widgets/order_status_badge.dart';

/// Reached via `pushReplacement` from checkout — the checkout route is gone
/// from the stack, so a system back goes to `/cart` (now empty), never to a
/// resubmittable form (§72/§73). [result] is a transient nav payload; the
/// order itself lives in Postgres (§45/§46).
class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.result});

  final CreateOrderResult? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    // Defensive: a hot-reload / stray deep link can land here with no
    // payload. Send the user to their (authoritative) order history.
    final order = result?.order;
    if (order == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(automaticallyImplyLeading: false),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(Routes.orders),
            child: Text(s('order.success.viewOrder')),
          ),
        ),
      );
    }

    return PopScope(
      // Back = "keep shopping"; it must not return to checkout.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(s('order.success.title')),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              NovaSpace.lg,
              NovaSpace.md,
              NovaSpace.lg,
              NovaSpace.xl,
            ),
            children: [
              const SizedBox(height: NovaSpace.sm),
              Center(child: _SuccessMark(color: c.success)),
              const SizedBox(height: NovaSpace.lg),
              Text(
                s('order.success.title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: NovaSpace.xs),
              Text(
                s('order.success.body'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: NovaSpace.xl),
              Container(
                padding: const EdgeInsets.all(NovaSpace.md),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(NovaRadii.md),
                  border: Border.all(color: c.border),
                  boxShadow: NovaShadows.card(Theme.of(context).brightness),
                ),
                child: Column(
                  children: [
                    _Row(
                      label: s('order.success.orderNumber'),
                      child: Text(
                        order.orderNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Row(
                      label: s('order.success.itemCount'),
                      child: Text('${order.itemCount}'),
                    ),
                    const SizedBox(height: 10),
                    _Row(
                      label: s('order.success.paymentStatus'),
                      child: PaymentStatusChip(
                        status: order.payment?.status ?? PaymentStatus.unknown,
                      ),
                    ),
                    const Divider(height: 22),
                    _Row(
                      label: s('order.success.total'),
                      child: Text(
                        Money.format(order.total),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.price,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NovaSpace.xl),
              FilledButton(
                onPressed: () =>
                    context.pushReplacement(Routes.order(order.id)),
                child: Text(s('order.success.viewOrder')),
              ),
              const SizedBox(height: NovaSpace.sm),
              OutlinedButton(
                onPressed: () => context.go(Routes.home),
                child: Text(s('order.success.continueShopping')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 13, color: c.text3)),
        ),
        const SizedBox(width: 12),
        Flexible(child: child),
      ],
    );
  }
}

/// Restrained check-mark reveal — a scale+fade tween, no animation package.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) =>
          Transform.scale(scale: 0.6 + 0.4 * t.clamp(0, 1), child: child),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, size: 40, color: color),
      ),
    );
  }
}
