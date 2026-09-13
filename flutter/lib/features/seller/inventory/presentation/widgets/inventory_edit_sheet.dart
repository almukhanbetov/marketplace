import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/models/localized_text.dart';
import '../../../../../shared/widgets/nova_text_field.dart';
import '../../data/seller_inventory_models.dart';

/// Bottom sheet to set an offer's available quantity. Validates `>= 0`
/// only — the backend is authoritative (Stage F6B §15). Returns the new
/// quantity, or null if cancelled / unchanged.
Future<int?> showInventoryEditSheet(
  BuildContext context,
  SellerInventoryItemModel item,
) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InventoryEditSheet(item: item),
  );
}

class _InventoryEditSheet extends ConsumerStatefulWidget {
  const _InventoryEditSheet({required this.item});
  final SellerInventoryItemModel item;

  @override
  ConsumerState<_InventoryEditSheet> createState() => _State();
}

class _State extends ConsumerState<_InventoryEditSheet> {
  late final _ctl = TextEditingController(
    text: '${widget.item.availableQuantity}',
  );
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _save() {
    final s = ref.read(appStringsProvider);
    final v = int.tryParse(_ctl.text.trim());
    if (v == null || v < 0) {
      setState(() => _error = s('seller.inventory.validation.quantity'));
      return;
    }
    if (v == widget.item.availableQuantity) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s('seller.inventory.editTitle'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.pick(widget.item.productName),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: c.text3),
          ),
          const SizedBox(height: 16),
          NovaTextField(
            label: s('seller.inventory.field.available'),
            controller: _ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          if (widget.item.reservedQuantity > 0) ...[
            const SizedBox(height: 6),
            Text(
              s(
                'seller.inventory.reservedNote',
              ).replaceFirst('{n}', '${widget.item.reservedQuantity}'),
              style: TextStyle(fontSize: 11.5, color: c.text3),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s('action.cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(s('action.save')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
