import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_store.dart';

/// NOVA offers exactly two looks — "Dark Premium" and "Light / Vivid" —
/// plus "follow system". Mirrors the web `ThemeContext` (which persists
/// `mp_theme` = `dark` | `vivid`); here we additionally allow `system`.
enum NovaThemeMode {
  system,
  dark,
  light;

  ThemeMode get material => switch (this) {
    NovaThemeMode.system => ThemeMode.system,
    NovaThemeMode.dark => ThemeMode.dark,
    NovaThemeMode.light => ThemeMode.light,
  };

  static NovaThemeMode fromStorage(String? raw) => switch (raw) {
    'dark' => NovaThemeMode.dark,
    'light' || 'vivid' => NovaThemeMode.light,
    _ => NovaThemeMode.system,
  };
}

class ThemeController extends Notifier<NovaThemeMode> {
  @override
  NovaThemeMode build() {
    final raw = ref.watch(preferencesStoreProvider).themeMode;
    return NovaThemeMode.fromStorage(raw);
  }

  Future<void> set(NovaThemeMode mode) async {
    state = mode;
    await ref.read(preferencesStoreProvider).setThemeMode(mode.name);
  }

  Future<void> toggleDarkLight() => set(
    state == NovaThemeMode.light ? NovaThemeMode.dark : NovaThemeMode.light,
  );
}

final themeControllerProvider =
    NotifierProvider<ThemeController, NovaThemeMode>(ThemeController.new);
