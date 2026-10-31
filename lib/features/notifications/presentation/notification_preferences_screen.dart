import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/settings_rules.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../data/models/user_preferences.dart';
import '../../settings/presentation/widgets/preference_tile.dart';
import '../../settings/providers/user_preferences_provider.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

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

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required bool start,
  }) async {
    final prefs = ref.read(userPreferencesProvider);
    final minutes = start ? prefs.quietStartMinutes : prefs.quietEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !context.mounted) return;
    final next = picked.hour * 60 + picked.minute;
    await _save(
      context,
      ref,
      (p) => start
          ? p.copyWith(quietStartMinutes: next)
          : p.copyWith(quietEndMinutes: next),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Notification preferences'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSection(
                  title: 'Delivery',
                  subtitle: 'Push delivery depends on your device settings.',
                  child: PreferenceTile(
                    icon: AppIcons.notifications,
                    title: 'Push notifications',
                    subtitle: 'A preference only. Nothing is delivered.',
                    value: prefs.pushEnabled,
                    onChanged: (v) =>
                        _save(context, ref, (p) => p.copyWith(pushEnabled: v)),
                  ),
                ),
                AppSection(
                  title: 'Types',
                  child: Column(
                    children: [
                      PreferenceTile(
                        icon: AppIcons.matches,
                        title: 'Matches',
                        value: prefs.notifyMatches,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(notifyMatches: v),
                        ),
                      ),
                      PreferenceTile(
                        icon: AppIcons.heart,
                        title: 'Likes',
                        value: prefs.notifyLikes,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(notifyLikes: v),
                        ),
                      ),
                      PreferenceTile(
                        icon: AppIcons.chat,
                        title: 'Messages',
                        value: prefs.notifyMessages,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(notifyMessages: v),
                        ),
                      ),
                      PreferenceTile(
                        icon: AppIcons.info,
                        title: 'Profile and account updates',
                        value: prefs.notifySystem,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(notifySystem: v),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSection(
                  title: 'Profile completion reminder',
                  subtitle: SettingsRules.reminderNote,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (final days in SettingsRules.reminderDayOptions)
                        ButtonSegment(value: days, label: Text('$days days')),
                    ],
                    selected: {prefs.profileReminderDays},
                    onSelectionChanged: (s) => _save(
                      context,
                      ref,
                      (p) => p.copyWith(profileReminderDays: s.first),
                    ),
                  ),
                ),
                AppSection(
                  title: 'Quiet hours',
                  subtitle: SettingsRules.quietHoursNote,
                  child: Column(
                    children: [
                      PreferenceTile(
                        icon: AppIcons.bedtime,
                        title: 'Quiet hours',
                        subtitle: SettingsRules.quietHoursLabel(
                          prefs.quietStartMinutes,
                          prefs.quietEndMinutes,
                        ),
                        value: prefs.quietHoursEnabled,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(quietHoursEnabled: v),
                        ),
                      ),
                      MenuTile(
                        icon: AppIcons.calendar,
                        title: 'Starts',
                        subtitle: SettingsRules.formatClock(
                          prefs.quietStartMinutes,
                        ),
                        onTap: () => _pickTime(context, ref, start: true),
                      ),
                      MenuTile(
                        icon: AppIcons.calendar,
                        title: 'Ends',
                        subtitle: SettingsRules.formatClock(
                          prefs.quietEndMinutes,
                        ),
                        onTap: () => _pickTime(context, ref, start: false),
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
