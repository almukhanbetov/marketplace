import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../addresses/data/address_models.dart';

/// Delivery-address picker for checkout. The default address is
/// auto-selected by the controller (§10); the user can pick another or add
/// one (§11). Shows the real backend fields (§12).
class AddressSelector extends ConsumerWidget {
  const AddressSelector({
    super.key,
    required this.addresses,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    this.enabled = true,
  });

  final List<AddressModel> addresses;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    if (addresses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s('checkout.noAddress.title'),
              style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
            ),
            const SizedBox(height: 4),
            Text(
              s('checkout.noAddress.body'),
              style: TextStyle(fontSize: 12.5, color: c.text2),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(s('checkout.addAddress')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final a in addresses)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AddressOption(
              address: a,
              selected: a.id == selectedId,
              onTap: enabled ? () => onSelect(a.id) : null,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(s('checkout.addAddress')),
          ),
        ),
      ],
    );
  }
}

class _AddressOption extends ConsumerWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final AddressModel address;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? c.accent : c.text3,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if ((address.title ?? '').isNotEmpty)
                          Flexible(
                            child: Text(
                              address.title!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              s('address.default'),
                              style: TextStyle(
                                fontSize: 10,
                                color: c.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${address.city}, ${address.oneLine}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.text2,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
