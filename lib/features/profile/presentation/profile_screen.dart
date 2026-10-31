import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../data/models/profile.dart';
import '../../auth/providers/session_provider.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../notifications/providers/notifications_providers.dart';
import '../providers/personal_profile_provider.dart';

/// Profile tab: the signed-in user's header and the hub for account
/// destinations (personal information, premium, notifications, settings).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final completion = ref.watch(personalProfileCompletionProvider);
    final name = session.displayName ?? 'You';
    final phone = session.phoneLabel;

    return AppPage(
      appBar: const AppTopBar(showBrand: true, actions: [NotificationBell()]),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.xl + kBottomNavigationBarHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Column(
                    children: [
                      ProfileAvatar(
                        name: name,
                        size: AppSizes.avatarXl,
                        showRing: true,
                      ),
                      AppSpacing.gapLg,
                      Semantics(
                        header: true,
                        child: Text(name, style: context.text.headlineLarge),
                      ),
                      if (phone != null)
                        Text(
                          phone,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.palette.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                AppSection(
                  title: 'Personal Information',
                  child: MenuTile(
                    icon: AppIcons.profile,
                    title: 'Your details',
                    subtitle:
                        '${completion.overallPercent}% · '
                        '${completion.progressLabel}',
                    onTap: () => context.push(AppRoutes.personalInfo),
                  ),
                ),
                AppSection(
                  title: 'Membership',
                  child: MenuTile(
                    icon: AppIcons.premium,
                    title: 'Premium',
                    subtitle: (session.gender?.hasComplimentaryPremium ?? false)
                        ? 'Included with your account'
                        : null,
                    onTap: () => context.push(AppRoutes.subscription),
                  ),
                ),
                AppSection(
                  title: 'Preferences',
                  child: Column(
                    children: [
                      MenuTile(
                        icon: AppIcons.notifications,
                        title: 'Notifications',
                        subtitle: unread > 0 ? '$unread unread' : null,
                        onTap: () => context.push(AppRoutes.notifications),
                      ),
                      MenuTile(
                        icon: AppIcons.settings,
                        title: 'Settings',
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                      MenuTile(
                        icon: AppIcons.account,
                        title: 'Account',
                        onTap: () => context.push(AppRoutes.account),
                      ),
                    ],
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
