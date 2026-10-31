import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_bottom_nav.dart';
import '../core/widgets/brand_mark.dart';
import '../features/auth/providers/session_provider.dart';
import '../features/chat/providers/chat_providers.dart';

/// Signed-in shell: hosts the five tab branches and the bottom navigation.
/// Each branch keeps its own navigation stack and scroll state.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chatHubControllerProvider);
    final unreadChats = ref.watch(chatPreviewsProvider.select(unreadCountOf));

    // While the profile is incomplete only discovery is reachable, so the other
    // tabs are hidden rather than shown and bounced back.
    final fullAccess = ref.watch(
      sessionProvider.select((session) => session.isLoggedIn),
    );

    // Discovery is a dark, photo-first screen, so its navigation bar is dark in
    // every theme.
    final darkNav = navigationShell.currentIndex == 0;

    Widget nav(Widget child) =>
        darkNav ? Theme(data: AppTheme.dark, child: child) : child;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: !fullAccess
          ? null
          : nav(
              AppBottomNav(
                currentIndex: navigationShell.currentIndex,
                destinations: [
                  const AppNavDestination(
                    iconWidget: BrandMark(size: 24),
                    label: 'Discover',
                  ),
                  const AppNavDestination(
                    icon: AppIcons.heartOutline,
                    selectedIcon: AppIcons.likes,
                    label: 'Likes',
                  ),
                  const AppNavDestination(
                    icon: AppIcons.matchesOutline,
                    selectedIcon: AppIcons.matches,
                    label: 'Matches',
                  ),
                  AppNavDestination(
                    icon: AppIcons.chatOutline,
                    selectedIcon: AppIcons.chat,
                    label: 'Chat',
                    badgeCount: unreadChats,
                  ),
                  const AppNavDestination(
                    icon: AppIcons.profileOutline,
                    selectedIcon: AppIcons.profile,
                    label: 'Profile',
                  ),
                ],
                onSelected: (index) => navigationShell.goBranch(
                  index,
                  // Tapping the active tab returns to its root.
                  initialLocation: index == navigationShell.currentIndex,
                ),
              ),
            ),
    );
  }
}
