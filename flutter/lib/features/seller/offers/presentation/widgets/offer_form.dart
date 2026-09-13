import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/nova_text_field.dart';

/// Client-side UX validation only — the backend stays authoritative
/// (Stage F6B §10). Mirrors the backend's `^[0-9]+(\.[0-9]{1,2})?$` money
/// rule so the obvious mistakes are caught before the round-trip.
final _moneyRe = RegExp(r'^[0-9]+(\.[0-9]{1,2})?$');

class OfferFormValues {
  const OfferFormValues({
    required this.sku,
    required this.price,
    required this.oldPrice,
    required this.deliveryDays,
    required this.stock,
  });

  final String sku;
  final String price;

  /// "" when the field is blank — the backend treats "" as "no old price".
  final String oldPrice;
  final int deliveryDays;

  /// Only meaningful when the form includes the stock field (create).
  final int stock;
}

/// Shared field layout + validation for Add / Edit offer. Renders its own
/// submit button; [onSubmit] returns an error string to show as a banner,
/// or null on success (the parent then navigates away).
class OfferForm extends ConsumerStatefulWidget {
  const OfferForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.includeStock = false,
    this.initialSku = '',
    this.initialPrice = '',
    this.initialOldPrice = '',
    this.initialDeliveryDays = 1,
    this.initialStock = 0,
  });

  final String submitLabel;
  final bool includeStock;
  final String initialSku;
  final String initialPrice;
  final String initialOldPrice;
  final int initialDeliveryDays;
  final int initialStock;
  final Future<String?> Function(OfferFormValues) onSubmit;

  @override
  ConsumerState<OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends ConsumerState<OfferForm> {
  late final _sku = TextEditingController(text: widget.initialSku);
  late final _price = TextEditingController(text: widget.initialPrice);
  late final _oldPrice = TextEditingController(text: widget.initialOldPrice);
  late final _delivery = TextEditingController(
    text: '${widget.initialDeliveryDays}',
  );
  late final _stock = TextEditingController(text: '${widget.initialStock}');

  final _errors = <String, String?>{};
  String? _banner;
  bool _busy = false;

  @override
  void dispose() {
    for (final ctl in [_sku, _price, _oldPrice, _delivery, _stock]) {
      ctl.dispose();
    }
    super.dispose();
  }

  bool _validate(AppStrings s) {
    final e = <String, String?>{};
    if (_sku.text.trim().isEmpty) {
      e['sku'] = s('seller.offers.validation.skuRequired');
    }
    if (!_moneyRe.hasMatch(_price.text.trim())) {
      e['price'] = s('seller.offers.validation.priceInvalid');
    }
    final old = _oldPrice.text.trim();
    if (old.isNotEmpty && !_moneyRe.hasMatch(old)) {
      e['oldPrice'] = s('seller.offers.validation.priceInvalid');
    }
    final d = int.tryParse(_delivery.text.trim());
    if (d == null || d < 0) {
      e['delivery'] = s('seller.offers.validation.deliveryInvalid');
    }
    if (widget.includeStock) {
      final st = int.tryParse(_stock.text.trim());
      if (st == null || st < 0) {
        e['stock'] = s('seller.offers.validation.stockInvalid');
      }
    }
    setState(
      () => _errors
        ..clear()
        ..addAll(e),
    );
    return e.isEmpty;
  }

  Future<void> _submit() async {
    final s = ref.read(appStringsProvider);
    FocusScope.of(context).unfocus();
    if (!_validate(s)) return;

    setState(() {
      _busy = true;
      _banner = null;
    });
    final err = await widget.onSubmit(
      OfferFormValues(
        sku: _sku.text.trim(),
        price: _price.text.trim(),
        oldPrice: _oldPrice.text.trim(),
        deliveryDays: int.parse(_delivery.text.trim()),
        stock: widget.includeStock ? int.parse(_stock.text.trim()) : 0,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _banner = err;
    });
  }

  void _clear(String k) {
    if (_errors[k] != null) setState(() => _errors[k] = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final digits = [FilteringTextInputFormatter.digitsOnly];

    // A Column, not a ListView — the parent screen owns the scroll so this
    // can be embedded under a product-summary tile.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_banner != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.dangerSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _banner!,
                style: TextStyle(color: c.danger, fontSize: 13),
              ),
            ),
          NovaTextField(
            label: s('seller.offers.field.sku'),
            controller: _sku,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            errorText: _errors['sku'],
            onChanged: (_) => _clear('sku'),
          ),
          const SizedBox(height: 14),
          NovaTextField(
            label: s('seller.offers.field.price'),
            controller: _price,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            errorText: _errors['price'],
            onChanged: (_) => _clear('price'),
          ),
          const SizedBox(height: 14),
          NovaTextField(
            label: s('seller.offers.field.oldPrice'),
            controller: _oldPrice,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            errorText: _errors['oldPrice'],
            onChanged: (_) => _clear('oldPrice'),
          ),
          const SizedBox(height: 4),
          Text(
            s('seller.offers.field.oldPriceHint'),
            style: TextStyle(fontSize: 11.5, color: c.text3),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NovaTextField(
                  label: s('seller.offers.field.deliveryDays'),
                  controller: _delivery,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  textInputAction: TextInputAction.next,
                  errorText: _errors['delivery'],
                  onChanged: (_) => _clear('delivery'),
                ),
              ),
              if (widget.includeStock) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: NovaTextField(
                    label: s('seller.offers.field.stock'),
                    controller: _stock,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    textInputAction: TextInputAction.done,
                    errorText: _errors['stock'],
                    onChanged: (_) => _clear('stock'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
