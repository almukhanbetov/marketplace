import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/preferences_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve SharedPreferences once so theme/locale can be read
  // synchronously everywhere via [sharedPreferencesProvider].
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Disable Riverpod 3's automatic retry-on-error. A failed catalog /
      // product / seller fetch should surface an ErrorView with a manual
      // "Retry" button immediately, not silently loop in the background
      // (which would also keep AsyncValue.isLoading true forever).
      retry: (_, _) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NovaApp(),
    ),
  );
}
