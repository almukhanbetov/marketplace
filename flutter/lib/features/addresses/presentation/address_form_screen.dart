import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/nova_text_field.dart';
import '../application/addresses_controller.dart';
import '../data/address_models.dart';

/// Full-screen create / edit form (§37/§38). Keyboard-safe scroll. Backend
/// is authoritative — the client only checks "not blank".
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});

  final AddressModel? existing;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _street = TextEditingController(
    text: widget.existing?.street ?? '',
  );
  late final _house = TextEditingController(text: widget.existing?.house ?? '');
  late final _apartment = TextEditingController(
    text: widget.existing?.apartment ?? '',
  );
  late final _postal = TextEditingController(
    text: widget.existing?.postalCode ?? '',
  );
  late bool _isDefault = widget.existing?.isDefault ?? false;

  bool _busy = false;
  final _errors = <String, String?>{};
  String? _banner;

  @override
  void dispose() {
    for (final ctl in [_title, _city, _street, _house, _apartment, _postal]) {
      ctl.dispose();
    }
    super.dispose();
  }

  bool _validate(AppStrings s) {
    final e = <String, String?>{};
    if (_city.text.trim().isEmpty) {
      e['city'] = s('address.validation.cityRequired');
    }
    if (_street.text.trim().isEmpty) {
      e['street'] = s('address.validation.streetRequired');
    }
    if (_house.text.trim().isEmpty) {
      e['house'] = s('address.validation.houseRequired');
    }
    setState(
      () => _errors
        ..clear()
        ..addAll(e),
    );
    return e.isEmpty;
  }

  Future<void> _save() async {
    final s = ref.read(appStringsProvider);
    FocusScope.of(context).unfocus();
    if (!_validate(s)) return;

    setState(() {
      _busy = true;
      _banner = null;
    });
    final input = AddressInput(
      title: _title.text,
      city: _city.text,
      street: _street.text,
      house: _house.text,
      apartment: _apartment.text,
      postalCode: _postal.text,
      isDefault: _isDefault,
    );
    final controller = ref.read(addressesControllerProvider.notifier);
    try {
      if (widget.existing == null) {
        await controller.create(input);
      } else {
        await controller.update(widget.existing!.id, input);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _banner = s.apiError(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear(String k) {
    if (_errors[k] != null) setState(() => _errors[k] = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          widget.existing == null ? s('address.add') : s('address.edit'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_banner != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
              label: s('address.field.title'),
              controller: _title,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            NovaTextField(
              label: s('address.field.city'),
              controller: _city,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.addressCity],
              errorText: _errors['city'],
              onChanged: (_) => _clear('city'),
            ),
            const SizedBox(height: 14),
            NovaTextField(
              label: s('address.field.street'),
              controller: _street,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.streetAddressLine1],
              errorText: _errors['street'],
              onChanged: (_) => _clear('street'),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NovaTextField(
                    label: s('address.field.house'),
                    controller: _house,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    errorText: _errors['house'],
                    onChanged: (_) => _clear('house'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NovaTextField(
                    label: s('address.field.apartment'),
                    controller: _apartment,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            NovaTextField(
              label: s('address.field.postalCode'),
              controller: _postal,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.postalCode],
              onSubmitted: (_) => _busy ? null : _save(),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isDefault,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _isDefault = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(s('address.setDefaultOnSave')),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(s('address.save')),
            ),
          ],
        ),
      ),
    );
  }
}
