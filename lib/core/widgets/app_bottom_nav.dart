import 'package:flutter/material.dart';

@immutable
class AppNavDestination {
  const AppNavDestination({
    this.icon,
    this.iconWidget,
    required this.label,
    this.selectedIcon,
    this.selectedIconWidget,
    this.badgeCount = 0,
  }) : assert(
         icon != null || iconWidget != null,
         'Provide an icon or an iconWidget.',
       );

  final IconData? icon;

  /// Custom mark (the brand logo on Discover). Used instead of [icon].
  final Widget? iconWidget;

  /// Shown while the destination is selected; defaults to [icon].
  final IconData? selectedIcon;
  final Widget? selectedIconWidget;
  final String label;

  /// Shows a count badge when greater than zero.
  final int badgeCount;
}

/// Bottom navigation. A thin wrapper over Material 3's [NavigationBar] (styled
/// in `AppTheme`) that adds count badges and spoken badge counts.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final d in destinations)
          NavigationDestination(
            icon: _badged(d, _mark(d, selected: false)),
            selectedIcon: _badged(d, _mark(d, selected: true)),
            label: d.label,
            tooltip: d.badgeCount > 0
                ? '${d.label}, ${d.badgeCount} unread'
                : d.label,
          ),
      ],
    );
  }

  Widget _mark(AppNavDestination d, {required bool selected}) {
    final custom = selected
        ? (d.selectedIconWidget ?? d.iconWidget)
        : d.iconWidget;
    if (custom != null) return custom;
    return Icon(selected ? (d.selectedIcon ?? d.icon!) : d.icon!);
  }

  Widget _badged(AppNavDestination d, Widget icon) => Badge(
    isLabelVisible: d.badgeCount > 0,
    label: Text(d.badgeCount > 99 ? '99+' : '${d.badgeCount}'),
    child: icon,
  );
}
