import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nova_section_label.dart';
import '../../../shared/widgets/nova_skeleton.dart';
import '../../../shared/widgets/nova_sticky_bar.dart';
import '../../addresses/application/addresses_controller.dart';
import '../../addresses/presentation/address_form_screen.dart';
import '../../cart/application/cart_controller.dart';
import '../application/checkout_controller.dart';
import 'widgets/address_selector.dart';
import 'widgets/checkout_summary.dart';
import 'widgets/payment_selector.dart';

/// Real checkout (Stage F5). Sends only `address_id` + `payment_provider`
/// (+ a stable `Idempotency-Key`); the backend owns prices, totals,
/// inventory and the cart-clear. Empty cart never reaches the API (§7).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    // If the address list is already loaded (the common path — the user
    // came from the cart), pick the default once, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectAddress());
  }

  void _autoSelectAddress() {
    if (!mounted) return;
    final a = ref.read(addressesControllerProvider);
    if (a.status == AddressesStatus.loaded && a.items.isNotEmpty) {
      ref
          .read(checkoutControllerProvider.notifier)
          .selectAddressIfUnset(a.defaultAddress?.id ?? a.items.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final cartState = ref.watch(cartControllerProvider);
    final addrState = ref.watch(addressesControllerProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);

    // Auto-select the default address when the list arrives asynchronously
    // (first login, or after adding an address here) (§10).
    ref.listen(addressesControllerProvider, (_, next) {
      if (next.status == AddressesStatus.loaded && next.items.isNotEmpty) {
        controller.selectAddressIfUnset(
          next.defaultAddress?.id ?? next.items.first.id,
        );
      }
    });

    // On success → replace this route so back can't resubmit (§72/§73).
    ref.listen(checkoutControllerProvider, (prev, next) {
      if (prev?.phase != CheckoutPhase.success &&
          next.phase == CheckoutPhase.success &&
          next.result != null) {
        context.pushReplacement(Routes.checkoutSuccess, extra: next.result);
      }
    });

    final cart = cartState.cart;
    final cartBusy =
        cartState.isFirstLoad || cartState.status == CartStatus.initial;

    Widget body;
    if (cartBusy) {
      body = const _CheckoutSkeleton();
    } else if (cartState.status == CartStatus.error && cart.isEmpty) {
      body = ErrorView(
        error: cartState.error,
        onRetry: ref.read(cartControllerProvider.notifier).refresh,
      );
    } else if (cart.isEmpty) {
      body = EmptyView(
        icon: Icons.shopping_bag_outlined,
        title: s('checkout.emptyCart.title'),
        body: s('checkout.emptyCart.body'),
        action: FilledButton(
          onPressed: () => context.go(Routes.catalog),
          child: Text(s('product.toCatalog')),
        ),
      );
    } else {
      body = _Form(
        checkout: checkout,
        addresses: addrState,
        onAddAddress: _openAddressForm,
      );
    }

    final showBar = !cartBusy && !cart.isEmpty;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('checkout.title'))),
      bottomNavigationBar: showBar
          ? _PlaceOrderBar(
              total: cart.subtotal,
              state: checkout,
              onPlace: controller.submit,
            )
          : null,
      body: SafeArea(bottom: false, child: body),
    );
  }

  Future<void> _openAddressForm() async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddressFormScreen()));
    if (mounted) {
      // The form's controller already re-read the list; this is belt-and-
      // braces so the auto-select listener has fresh data.
      ref.read(addressesControllerProvider.notifier).refresh();
    }
  }
}

class _Form extends ConsumerWidget {
  const _Form({
    required this.checkout,
    required this.addresses,
    required this.onAddAddress,
  });

  final CheckoutState checkout;
  final AddressesState addresses;
  final VoidCallback onAddAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final cart = ref.watch(cartControllerProvider).cart;
    final controller = ref.read(checkoutControllerProvider.notifier);
    final enabled = !checkout.isSubmitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NovaSpace.md,
        NovaSpace.xs,
        NovaSpace.md,
        NovaSpace.xl,
      ),
      children: [
        if (checkout.errorCode != null) ...[
          _ErrorBanner(code: checkout.errorCode!),
          const Gap(NovaSpace.md),
        ],

        _SectionTitle(s('checkout.section.summary')),
        const Gap(NovaSpace.xs),
        CheckoutSummary(cart: cart),
        const Gap(NovaSpace.lg),

        _SectionTitle(s('checkout.section.address')),
        const Gap(NovaSpace.xs),
        if (addresses.status == AddressesStatus.loading &&
            addresses.items.isEmpty)
          const NovaSkeleton(height: 72)
        else
          AddressSelector(
            addresses: addresses.items,
            selectedId: checkout.selectedAddressId,
            onSelect: controller.selectAddress,
            onAdd: onAddAddress,
            enabled: enabled,
          ),
        const Gap(NovaSpace.lg),

        _SectionTitle(s('checkout.section.payment')),
        const Gap(NovaSpace.xs),
        PaymentSelector(
          selected: checkout.payment,
          onSelect: controller.selectPayment,
          enabled: enabled,
        ),
      ],
    );
  }
}

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    final (message, showBackToCart) = switch (code) {
      'INSUFFICIENT_STOCK' => (s('checkout.error.stock'), true),
      'OFFER_UNAVAILABLE' ||
      'SELLER_OFFER_NOT_FOUND' => (s('checkout.error.offer'), true),
      'ADDRESS_NOT_FOUND' => (s('checkout.error.address'), false),
      'CART_EMPTY' => (s('error.CART_EMPTY'), true),
      _ => (s.apiError(code), false),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: c.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.danger,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (showBackToCart) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => context.go(Routes.cart),
                child: Text(s('checkout.error.backToCart')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceOrderBar extends ConsumerWidget {
  const _PlaceOrderBar({
    required this.total,
    required this.state,
    required this.onPlace,
  });

  final String total;
  final CheckoutState state;
  final Future<void> Function() onPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final busy = state.isSubmitting;

    return NovaStickyBar(
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s('checkout.summary.total'),
                style: TextStyle(fontSize: 11.5, color: c.text3),
              ),
              Text(
                Money.format(total),
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
            child: Semantics(
              button: true,
              enabled: state.canSubmit,
              label: busy ? s('checkout.processing') : s('checkout.placeOrder'),
              child: FilledButton(
                onPressed: state.canSubmit && !busy ? onPlace : null,
                child: busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              s('checkout.processing'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        state.errorCode != null
                            ? s('action.retry')
                            : s('checkout.placeOrder'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      NovaSectionLabel(text, padding: EdgeInsets.zero);
}

class _CheckoutSkeleton extends StatelessWidget {
  const _CheckoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(NovaSpace.md),
      children: const [
        NovaSkeleton(
          height: 140,
          margin: EdgeInsets.only(bottom: NovaSpace.md),
        ),
        NovaSkeleton(height: 96, margin: EdgeInsets.only(bottom: NovaSpace.md)),
        NovaSkeleton(
          height: 180,
          margin: EdgeInsets.only(bottom: NovaSpace.md),
        ),
      ],
    );
  }
}
