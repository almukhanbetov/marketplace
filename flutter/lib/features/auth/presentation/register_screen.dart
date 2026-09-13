import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/nova_text_field.dart';
import '../application/auth_error_mapper.dart';
import 'application_landing.dart';
import 'widgets/auth_scaffold.dart';

/// Real registration (Stage F2 §22). Always creates a `customer` account —
/// there is no role field. Email is required by this UI; phone is
/// optional (the backend accepts either, but a single required identifier
/// keeps the form simple).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _banner;
  final _errors = <String, String?>{};

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    for (final ctl in [_name, _email, _phone, _password, _confirm]) {
      ctl.dispose();
    }
    super.dispose();
  }

  bool _validate(AppStrings s) {
    final e = <String, String?>{};
    if (_name.text.trim().isEmpty) {
      e['name'] = s('auth.validation.nameRequired');
    }
    final email = _email.text.trim();
    if (email.isEmpty) {
      e['email'] = s('auth.validation.emailRequired');
    } else if (!_emailRe.hasMatch(email)) {
      e['email'] = s('auth.validation.emailInvalid');
    }
    final pw = _password.text;
    if (pw.isEmpty) {
      e['password'] = s('auth.validation.passwordRequired');
    } else if (pw.length < 8) {
      e['password'] = s('auth.validation.passwordTooShort');
    } else if (!RegExp(r'[A-Za-z]').hasMatch(pw) ||
        !RegExp(r'\d').hasMatch(pw)) {
      e['password'] = s('auth.validation.passwordNeedsLetterDigit');
    }
    if (_confirm.text != pw) {
      e['confirm'] = s('auth.validation.passwordsDontMatch');
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(e);
    });
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

    try {
      final role = await ref
          .read(authControllerProvider.notifier)
          .register(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      context.go(landingRouteFor(role, returnTo: widget.returnTo));
    } on Object catch (err) {
      if (!mounted) return;
      final mapped = mapAuthError(err, s);
      setState(() {
        switch (mapped.field) {
          case AuthErrorField.email:
            _errors['email'] = mapped.message;
          case AuthErrorField.phone:
            _errors['phone'] = mapped.message;
          case AuthErrorField.password:
            _errors['password'] = mapped.message;
          case AuthErrorField.identifier:
          case AuthErrorField.none:
            _banner = mapped.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearError(String key) {
    if (_errors[key] != null) setState(() => _errors[key] = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return AuthScaffold(
      title: s('auth.register.title'),
      subtitle: s('auth.register.subtitle'),
      footer: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              s('auth.action.haveAccount'),
              style: TextStyle(color: c.text2, fontSize: 13.5),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.go(Routes.login),
              child: Text(s('auth.action.toLogin')),
            ),
          ],
        ),
      ),
      children: [
        if (_banner != null) AuthErrorBanner(message: _banner!),
        AutofillGroup(
          child: Column(
            children: [
              NovaTextField(
                label: s('auth.field.fullName'),
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                errorText: _errors['name'],
                onChanged: (_) => _clearError('name'),
              ),
              const SizedBox(height: 14),
              NovaTextField(
                label: s('auth.field.email'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                errorText: _errors['email'],
                onChanged: (_) => _clearError('email'),
              ),
              const SizedBox(height: 14),
              NovaTextField(
                label: s('auth.field.phoneOptional'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                ],
                errorText: _errors['phone'],
                onChanged: (_) => _clearError('phone'),
              ),
              const SizedBox(height: 14),
              NovaTextField(
                label: s('auth.field.password'),
                controller: _password,
                enabled: !_busy,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                errorText: _errors['password'],
                onChanged: (_) => _clearError('password'),
              ),
              const SizedBox(height: 14),
              NovaTextField(
                label: s('auth.field.confirmPassword'),
                controller: _confirm,
                enabled: !_busy,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                errorText: _errors['confirm'],
                onChanged: (_) => _clearError('confirm'),
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(s('auth.busy.register')),
                  ],
                )
              : Text(s('action.register')),
        ),
      ],
    );
  }
}
