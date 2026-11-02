import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/wallet/presentation/widgets/points_balance_chip.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import 'brand_mark.dart';

/// The one top app bar used by every screen: left-aligned title (or the brand
/// lock-up on tab roots), a rounded back button when there is somewhere to go
/// back to, and trailing [actions].
class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBrand = false,
    this.showPoints,
    this.transparent = false,
    this.circleBack = false,
    this.actions = const [],
  }) : assert(
         title != null || titleWidget != null || showBrand,
         'Provide a title, titleWidget, or set showBrand for tab roots.',
       );

  final String? title;

  /// Replaces the default title text (conversation header with avatar).
  final Widget? titleWidget;

  /// Shows the logo mark instead of [title] (tab roots).
  final bool showBrand;

  /// Shows spendable points before [actions]. Defaults on with [showBrand];
  /// pass `false` to hide on a branded bar.
  final bool? showPoints;

  /// Lets branded atmosphere show through (create-account and similar).
  final bool transparent;

  /// Outlined circular back control, used on cinematic auth screens.
  final bool circleBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.of(context).canPop();
    final pointsVisible = showPoints ?? showBrand;

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      forceMaterialTransparency: transparent,
      backgroundColor: transparent ? Colors.transparent : null,
      surfaceTintColor: transparent ? Colors.transparent : null,
      titleSpacing: canPop ? 0 : AppSpacing.pageGutter,
      leading: canPop
          ? IconButton(
              tooltip: 'Back',
              style: circleBack
                  ? IconButton.styleFrom(
                      side: BorderSide(color: context.palette.outlineSoft),
                      shape: const CircleBorder(),
                    )
                  : null,
              icon: const Icon(AppIcons.back),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: showBrand
          ? const BrandMark(size: 28)
          : titleWidget ??
                Semantics(
                  header: true,
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
      actions: [
        if (pointsVisible) const PointsBalanceChip(),
        ...actions,
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}
