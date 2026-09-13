import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// The kind of a transient message — picks the leading icon and accent
/// stripe colour (§36). Shape, position and duration stay identical across
/// all four so notifications feel like one system.
enum NovaSnackType { success, error, warning, info }

/// One entry point for every snackbar in the app. Replaces scattered
/// `ScaffoldMessenger…showSnackBar(SnackBar(content: Text(...)))` calls so
/// success / error / warning / info all share a look (§36).
abstract final class NovaSnackbar {
  static void show(
    BuildContext context,
    String message, {
    NovaSnackType type = NovaSnackType.info,
    SnackBarAction? action,
  }) {
    final c = context.nova;
    final (icon, tint) = switch (type) {
      NovaSnackType.success => (Icons.check_circle_rounded, c.success),
      NovaSnackType.error => (Icons.error_rounded, c.danger),
      NovaSnackType.warning => (Icons.warning_amber_rounded, c.warning),
      NovaSnackType.info => (Icons.info_rounded, c.accent),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: type == NovaSnackType.error
              ? const Duration(seconds: 5)
              : const Duration(seconds: 3),
          content: Row(
            children: [
              Container(width: 3, height: 26, color: tint),
              const SizedBox(width: NovaSpace.sm),
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: NovaSpace.xs),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          action: action,
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: NovaSnackType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: NovaSnackType.error);
}

/// A confirm dialog with NOVA styling. Returns `true` only when the user
/// taps the confirm action. Used for every destructive action —
/// remove-from-cart, clear cart, delete address, log out everywhere (§37).
///
/// [destructive] paints the confirm button in the danger colour; the
/// cancel label falls back to the platform-localized "Cancel" string when
/// not given.
Future<bool> novaConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final c = context.nova;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        NovaSpace.sm,
        0,
        NovaSpace.sm,
        NovaSpace.sm,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            cancelLabel ?? MaterialLocalizations.of(ctx).cancelButtonLabel,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: c.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
