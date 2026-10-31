import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../auth/providers/session_provider.dart';
import '../providers/theme_mode_provider.dart';

/// App settings: appearance, shortcuts to safety and account, and (in debug
/// builds only) the design system and mock controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Settings'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSection(
                  title: 'Appearance',
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
                  title: 'Preferences',
                  child: Column(
                    children: [
                      MenuTile(
                        icon: AppIcons.notifications,
                        title: 'Notification preferences',
                        subtitle: 'Push, reminders and quiet hours',
                        onTap: () =>
                            context.push(AppRoutes.notificationPreferences),
                      ),
                      MenuTile(
                        icon: AppIcons.lock,
                        title: 'Privacy',
                        subtitle: 'What is public and what stays private',
                        onTap: () => context.push(AppRoutes.privacy),
                      ),
                      MenuTile(
                        icon: AppIcons.accessibility,
                        title: 'Accessibility and theme',
                        onTap: () => context.push(AppRoutes.accessibility),
                      ),
                    ],
                  ),
                ),
                AppSection(
                  title: 'Privacy and safety',
                  child: Column(
                    children: [
                      MenuTile(
                        icon: AppIcons.heartOutline,
                        title: 'Match preferences',
                        onTap: () => context.push(AppRoutes.matchPreferences),
                      ),
                      MenuTile(
                        icon: AppIcons.safety,
                        title: 'Safety center',
                        onTap: () => context.push(AppRoutes.safety),
                      ),
                      MenuTile(
                        icon: AppIcons.block,
                        title: 'Blocked users',
                        onTap: () => context.push(AppRoutes.blockedUsers),
                      ),
                      MenuTile(
                        icon: AppIcons.account,
                        title: 'Account',
                        onTap: () => context.push(AppRoutes.account),
                      ),
                    ],
                  ),
                ),
                AppSection(
                  title: 'Help and legal',
                  child: Column(
                    children: [
                      MenuTile(
                        icon: AppIcons.help,
                        title: 'Help center',
                        onTap: () => context.push(AppRoutes.help),
                      ),
                      MenuTile(
                        icon: AppIcons.document,
                        title: 'Terms of Service',
                        onTap: () => context.push(AppRoutes.legalTerms),
                      ),
                      MenuTile(
                        icon: AppIcons.shield,
                        title: 'Privacy Policy',
                        onTap: () => context.push(AppRoutes.legalPrivacy),
                      ),
                    ],
                  ),
                ),
                if (kDebugMode)
                  AppSection(
                    title: 'Developer',
                    child: Column(
                      children: [
                        MenuTile(
                          icon: AppIcons.palette,
                          title: 'Design system and mock controls',
                          subtitle: 'Debug builds only',
                          onTap: () => context.push(AppRoutes.designPreview),
                        ),
                        MenuTile(
                          icon: AppIcons.sessionExpired,
                          title: 'Simulate expired session',
                          subtitle: 'Debug builds only',
                          onTap: () => ref
                              .read(sessionProvider.notifier)
                              .expireSession(),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: AppSpacing.pagePadding,
                  child: Text(
                    '${AppConstants.appName} 0.1.0',
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
