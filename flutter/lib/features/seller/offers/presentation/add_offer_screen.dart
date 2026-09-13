import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/localized_text.dart';
import '../../../../shared/widgets/nova_network_image.dart';
import '../../../catalog/data/catalog_models.dart';
import '../application/seller_offers_controller.dart';
import '../data/seller_offer_models.dart';
import 'widgets/offer_form.dart';
import 'widgets/product_selector_screen.dart';

/// Add a seller offer against an **existing** catalog product (Stage F6B
/// §7). Step 1: pick the product from the public catalog. Step 2: SKU /
/// price / old price / delivery / stock. The backend creates only the
/// offer row — never a product.
class AddOfferScreen extends ConsumerStatefulWidget {
  const AddOfferScreen({super.key});

  @override
  ConsumerState<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends ConsumerState<AddOfferScreen> {
  ProductCardModel? _product;

  Future<void> _pickProduct() async {
    final picked = await Navigator.of(context).push<ProductCardModel>(
      MaterialPageRoute(builder: (_) => const ProductSelectorScreen()),
    );
    if (picked != null && mounted) setState(() => _product = picked);
  }

  Future<String?> _submit(OfferFormValues v) async {
    final s = ref.read(appStringsProvider);
    final product = _product;
    if (product == null) return s('seller.offers.validation.productRequired');
    try {
      await ref
          .read(sellerOffersControllerProvider.notifier)
          .createOffer(
            NewOfferInput(
              productId: product.id,
              sku: v.sku,
              price: v.price,
              oldPrice: v.oldPrice,
              deliveryDays: v.deliveryDays,
              stock: v.stock,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s('seller.offers.created'))));
        context.pop();
      }
      return null;
    } on ApiException catch (e) {
      return s.apiError(e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s('seller.offers.add'))),
      body: SafeArea(
        child: _product == null
            ? _PickPrompt(onPick: _pickProduct)
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _SelectedProduct(product: _product!, onChange: _pickProduct),
                  OfferForm(
                    includeStock: true,
                    submitLabel: s('seller.offers.add'),
                    onSubmit: _submit,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PickPrompt extends ConsumerWidget {
  const _PickPrompt({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 44, color: c.text3),
            const SizedBox(height: 14),
            Text(
              s('seller.offers.productSelect.prompt'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.text2, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(s('seller.offers.productSelect.cta')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedProduct extends ConsumerWidget {
  const _SelectedProduct({required this.product, required this.onChange});
  final ProductCardModel product;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: NovaNetworkImage(
              url: product.primaryImage,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.pick(product.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  product.brand,
                  style: TextStyle(fontSize: 11.5, color: c.text3),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(s('seller.offers.productSelect.change')),
          ),
        ],
      ),
    );
  }
}
