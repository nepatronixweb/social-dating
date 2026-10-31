import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/theme/app_colors.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/settings/presentation/settings_screen.dart';

import 'helpers/pump_app.dart';

ThemeMode _themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

void main() {
  Future<void> openSettings(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    await pumpApp(
      tester,
      location: AppRoutes.settings,
      session: AuthStatus.loggedIn,
      prefs: prefs,
    );
    await pumpFrames(tester);
  }

  group('theme switching', () {
    testWidgets('defaults to following the system', (tester) async {
      await openSettings(tester);
      expect(_themeMode(tester), ThemeMode.system);
    });

    testWidgets('selecting Dark switches the whole app to dark', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await openSettings(tester);
      expect(_brightness(tester), Brightness.light);

      await tester.tap(find.text('Dark'));
      await pumpFrames(tester);

      expect(_themeMode(tester), ThemeMode.dark);
      expect(_brightness(tester), Brightness.dark);
    });

    testWidgets('selecting Light overrides a dark system', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await openSettings(tester);
      expect(_brightness(tester), Brightness.dark);

      await tester.tap(find.text('Light'));
      await pumpFrames(tester);

      expect(_themeMode(tester), ThemeMode.light);
      expect(_brightness(tester), Brightness.light);
    });

    testWidgets('the choice is persisted', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Dark'));
      await pumpFrames(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pref.theme_mode'), 'dark');

      await tester.tap(find.text('System'));
      await pumpFrames(tester);
      expect(prefs.getString('pref.theme_mode'), 'system');
    });

    testWidgets('a saved choice is applied on launch', (tester) async {
      await openSettings(tester, prefs: {'pref.theme_mode': 'dark'});
      expect(_themeMode(tester), ThemeMode.dark);
      expect(_brightness(tester), Brightness.dark);
    });

    testWidgets('the selector reflects the current mode', (tester) async {
      await openSettings(tester, prefs: {'pref.theme_mode': 'light'});
      final selector = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(selector.selected, {ThemeMode.light});
    });

    testWidgets('light and dark use different palettes and surfaces', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await openSettings(tester);
      final context = tester.element(find.byType(SettingsScreen));
      final lightBackground = Theme.of(context).scaffoldBackgroundColor;
      final lightPalette = Theme.of(context).extension<AppPalette>()!;

      await tester.tap(find.text('Dark'));
      await pumpFrames(tester);
      final darkContext = tester.element(find.byType(SettingsScreen));
      final darkBackground = Theme.of(darkContext).scaffoldBackgroundColor;
      final darkPalette = Theme.of(darkContext).extension<AppPalette>()!;

      expect(darkBackground, isNot(lightBackground));
      expect(darkPalette.pageBackground, isNot(lightPalette.pageBackground));
      expect(darkPalette.textMuted, isNot(lightPalette.textMuted));
    });
  });
}
