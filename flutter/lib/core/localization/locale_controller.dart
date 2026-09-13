import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_store.dart';
import 'app_locale.dart';

class LocaleController extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    return AppLocale.fromCode(ref.watch(preferencesStoreProvider).locale);
  }

  Future<void> set(AppLocale locale) async {
    state = locale;
    await ref.read(preferencesStoreProvider).setLocale(locale.code);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, AppLocale>(
  LocaleController.new,
);
