import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/data/payment_method.dart';

/// Mock payment providers (§13/§14). Every configured method is shown on
/// both platforms — payments are simulated in F5, so there's nothing to
/// hide (§15). The mock notice sits under the list.
class PaymentSelector extends ConsumerWidget {
  const PaymentSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.enabled = true,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Column(
      children: [
        for (final m in PaymentMethod.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              inMutuallyExclusiveGroup: true,
              selected: m == selected,
              button: true,
              label: s(m.labelKey),
              child: InkWell(
                onTap: enabled ? () => onSelect(m) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: m == selected ? c.accent : c.border,
                      width: m == selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(m.icon, size: 20, color: c.text2),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s(m.labelKey),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        m == selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: m == selected ? c.accent : c.text3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 13, color: c.text3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s('checkout.mockPaymentNotice'),
                style: TextStyle(fontSize: 11.5, color: c.text3, height: 1.3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
