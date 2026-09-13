import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/nova_text_field.dart';
import 'application_landing.dart';
import 'widgets/auth_scaffold.dart';
import '../application/auth_error_mapper.dart';

/// Real login (Stage F2 §21). Email OR phone + password. Backend is
/// authoritative; the client validates only for a fast "you left this
/// blank" response.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.returnTo});

  /// Route the user was trying to reach before the guard sent them here.
  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _identifierError;
  String? _passwordError;
  String? _banner;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate(AppStrings s) {
    setState(() {
      _identifierError = _identifier.text.trim().isEmpty
          ? s('auth.validation.identifierRequired')
          : null;
      _passwordError = _password.text.isEmpty
          ? s('auth.validation.passwordRequired')
          : null;
    });
    return _identifierError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    final s = ref.read(appStringsProvider);
    FocusScope.of(context).unfocus();
    if (!_validate(s)) return;

    setState(() {
      _busy = true;
      _banner = null;
      _identifierError = null;
      _passwordError = null;
    });

    try {
      final role = await ref
          .read(authControllerProvider.notifier)
          .login(identifier: _identifier.text.trim(), password: _password.text);
      if (!mounted) return;
      context.go(landingRouteFor(role, returnTo: widget.returnTo));
    } on Object catch (e) {
      if (!mounted) return;
      final mapped = mapAuthError(e, s);
      setState(() {
        switch (mapped.field) {
          case AuthErrorField.password:
            _passwordError = mapped.message;
          case AuthErrorField.identifier:
          case AuthErrorField.email:
          case AuthErrorField.phone:
            _identifierError = mapped.message;
          case AuthErrorField.none:
            _banner = mapped.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return AuthScaffold(
      title: s('auth.login.title'),
      subtitle: s('auth.login.subtitle'),
      footer: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              s('auth.action.noAccount'),
              style: TextStyle(color: c.text2, fontSize: 13.5),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => context.go(_withReturnTo(Routes.register)),
              child: Text(s('auth.action.toRegister')),
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
                label: s('auth.field.identifier'),
                controller: _identifier,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                errorText: _identifierError,
                onChanged: (_) {
                  if (_identifierError != null) {
                    setState(() => _identifierError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              NovaTextField(
                label: s('auth.field.password'),
                controller: _password,
                enabled: !_busy,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                errorText: _passwordError,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? _BusyLabel(text: s('auth.busy.login'))
              : Text(s('action.login')),
        ),
      ],
    );
  }

  String _withReturnTo(String base) {
    final rt = widget.returnTo;
    if (rt == null || rt.isEmpty) return base;
    return '$base?from=${Uri.encodeComponent(rt)}';
  }
}

class _BusyLabel extends StatelessWidget {
  const _BusyLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(text),
      ],
    );
  }
}
