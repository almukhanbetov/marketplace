import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_strings.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/money.dart';
import '../../../../../shared/widgets/nova_text_field.dart';
import '../../application/payout_request_controller.dart';

/// Bottom sheet to request a payout. Client UX validation only —
/// `amount > 0` and `amount <= availableBalance` (§8); the backend stays
/// authoritative. **No bank / account / card fields** (§14). Only the
/// available balance is withdrawable — pending is shown but not (§9).
Future<void> showRequestPayoutSheet(
  BuildContext context, {
  required String availableBalance,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RequestPayoutSheet(availableBalance: availableBalance),
  );
}

class _RequestPayoutSheet extends ConsumerStatefulWidget {
  const _RequestPayoutSheet({required this.availableBalance});
  final String availableBalance;

  @override
  ConsumerState<_RequestPayoutSheet> createState() => _State();
}

class _State extends ConsumerState<_RequestPayoutSheet> {
  final _ctl = TextEditingController();
  String? _fieldError;

  double get _available => Money.toDouble(widget.availableBalance);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool _validate(AppStrings s) {
    final raw = _ctl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null || v <= 0) {
      setState(() => _fieldError = s('payout.request.error.positive'));
      return false;
    }
    if (v > _available + 0.001) {
      setState(() => _fieldError = s('payout.request.error.overAvailable'));
      return false;
    }
    setState(() => _fieldError = null);
    return true;
  }

  Future<void> _submit() async {
    final s = ref.read(appStringsProvider);
    FocusScope.of(context).unfocus();
    if (!_validate(s)) return;
    await ref
        .read(payoutRequestControllerProvider.notifier)
        .submit(_ctl.text.trim().replaceAll(',', '.'));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;
    final req = ref.watch(payoutRequestControllerProvider);

    // Close on success.
    ref.listen(payoutRequestControllerProvider, (prev, next) {
      if (prev?.phase != PayoutRequestPhase.success &&
          next.phase == PayoutRequestPhase.success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(s('payout.request.submitted'))),
          );
      }
    });

    final bannerCode = req.errorCode;
    final banner = req.phase == PayoutRequestPhase.error
        ? (bannerCode == 'INSUFFICIENT_AVAILABLE_BALANCE'
              ? s('error.INSUFFICIENT_AVAILABLE_BALANCE')
              : (bannerCode != null
                    ? s.apiError(bannerCode)
                    : s('error.UNKNOWN_ERROR')))
        : null;

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
            s('payout.request.title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s(
              'payout.request.availableHint',
            ).replaceFirst('{v}', Money.format(widget.availableBalance)),
            style: TextStyle(fontSize: 12.5, color: c.text2),
          ),
          const SizedBox(height: 2),
          Text(
            s('payout.request.pendingNote'),
            style: TextStyle(fontSize: 11.5, color: c.text3),
          ),
          const SizedBox(height: 14),
          if (banner != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.dangerSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                banner,
                style: TextStyle(color: c.danger, fontSize: 13),
              ),
            ),
          NovaTextField(
            label: s('payout.request.field.amount'),
            controller: _ctl,
            autofocus: true,
            enabled: !req.isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            errorText: _fieldError,
            onChanged: (_) {
              if (_fieldError != null) setState(() => _fieldError = null);
            },
            onSubmitted: (_) => req.isSubmitting ? null : _submit(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: req.isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(s('action.cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: req.isSubmitting ? null : _submit,
                  child: req.isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          bannerCode != null
                              ? s('action.retry')
                              : s('payout.request.submit'),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
