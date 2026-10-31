import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/service_providers.dart';

/// Current [ThemeMode], persisted in SharedPreferences.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(localPreferencesServiceProvider).themeMode;

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(localPreferencesServiceProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
