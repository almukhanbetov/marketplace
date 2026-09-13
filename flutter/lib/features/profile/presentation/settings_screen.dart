import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/theme_controller.dart';

/// Real in F1 — language and theme are foundation features. Proves RU/KAZ/
/// ENG switching and Dark/Light/System switching end to end.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(s('settings.language')),
          RadioGroup<AppLocale>(
            groupValue: locale,
            onChanged: (v) {
              if (v != null) ref.read(localeControllerProvider.notifier).set(v);
            },
            child: Column(
              children: [
                for (final l in AppLocale.values)
                  RadioListTile<AppLocale>(value: l, title: Text(l.label)),
              ],
            ),
          ),
          const Divider(height: 24),
          _SectionHeader(s('settings.theme')),
          RadioGroup<NovaThemeMode>(
            groupValue: themeMode,
            onChanged: (v) {
              if (v != null) ref.read(themeControllerProvider.notifier).set(v);
            },
            child: Column(
              children: [
                RadioListTile<NovaThemeMode>(
                  value: NovaThemeMode.system,
                  title: Text(s('settings.theme.system')),
                ),
                RadioListTile<NovaThemeMode>(
                  value: NovaThemeMode.dark,
                  title: Text(s('settings.theme.dark')),
                ),
                RadioListTile<NovaThemeMode>(
                  value: NovaThemeMode.light,
                  title: Text(s('settings.theme.light')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
