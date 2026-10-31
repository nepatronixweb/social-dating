import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../data/models/user_preferences.dart';
import '../providers/theme_mode_provider.dart';
import '../providers/user_preferences_provider.dart';
import 'widgets/preference_tile.dart';

class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    UserPreferences Function(UserPreferences current) fn,
  ) async {
    try {
      await ref.read(userPreferencesProvider.notifier).update(fn);
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    final themeMode = ref.watch(themeModeProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Accessibility and theme'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSection(
                  title: 'Theme',
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).setMode(s.first),
                  ),
                ),
                AppSection(
                  title: 'Motion and text',
                  child: Column(
                    children: [
                      PreferenceTile(
                        icon: AppIcons.accessibility,
                        title: 'Reduce motion',
                        subtitle:
                            'Turns off in-app motion. This is not a system '
                            'setting.',
                        value: prefs.reduceMotion,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(reduceMotion: v),
                        ),
                      ),
                      PreferenceTile(
                        icon: AppIcons.textSize,
                        title: 'Bold text',
                        subtitle:
                            'Adds bold text on top of your system setting.',
                        value: prefs.boldText,
                        onChanged: (v) =>
                            _save(context, ref, (p) => p.copyWith(boldText: v)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: AppSpacing.pagePadding.copyWith(
                    bottom: AppSpacing.xxl,
                  ),
                  child: Text(
                    'Saved on this device only.',
                    style: context.text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
