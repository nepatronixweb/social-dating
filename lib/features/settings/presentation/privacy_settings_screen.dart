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
import '../../../data/models/user_preferences.dart';
import '../providers/user_preferences_provider.dart';
import 'widgets/preference_tile.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

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

    return AppPage(
      appBar: const AppTopBar(title: 'Privacy'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSection(
                  title: 'Shown on your profile',
                  subtitle: 'Other people can see these fields.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (title, body) in SettingsRules.publicFields)
                        _FieldRow(
                          icon: AppIcons.visibility,
                          title: title,
                          body: body,
                        ),
                    ],
                  ),
                ),
                AppSection(
                  title: 'Kept private',
                  subtitle: 'Never shown on a profile card.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (title, body) in SettingsRules.privateFields)
                        _FieldRow(
                          icon: AppIcons.lock,
                          title: title,
                          body: body,
                        ),
                    ],
                  ),
                ),
                AppSection(
                  title: 'Choices',
                  child: Column(
                    children: [
                      PreferenceTile(
                        icon: AppIcons.discover,
                        title: 'Show me in discovery',
                        subtitle: 'Others may see your public profile card.',
                        value: prefs.showInDiscovery,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(showInDiscovery: v),
                        ),
                      ),
                      PreferenceTile(
                        icon: AppIcons.location,
                        title: 'Approximate distance',
                        subtitle:
                            'City-level only. Exact location is never shown.',
                        value: prefs.showApproximateDistance,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(showApproximateDistance: v),
                        ),
                      ),
                      PreferenceTile(
                        icon: AppIcons.bolt,
                        title: 'Active status',
                        value: prefs.showActiveStatus,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(showActiveStatus: v),
                        ),
                      ),
                      PreferenceTile(
                        icon: AppIcons.work,
                        title: 'Occupation',
                        value: prefs.showOccupation,
                        onChanged: (v) => _save(
                          context,
                          ref,
                          (p) => p.copyWith(showOccupation: v),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: AppSpacing.pagePadding.copyWith(
                    bottom: AppSpacing.xxl,
                  ),
                  child: Text(
                    'Saved on this device only. Phone numbers and exact '
                    'locations are never listed here.',
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

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                AppSpacing.gapXs,
                Text(
                  body,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
