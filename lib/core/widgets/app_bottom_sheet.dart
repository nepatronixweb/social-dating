import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Shows a modal bottom sheet that handles safe areas, keyboard insets and
/// tall content (scrolls, capped at 90% of screen height).
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) =>
        AppBottomSheet(title: title, child: builder(sheetContext)),
  );
}

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.palette.outlineSoft,
                        borderRadius: AppRadii.borderPill,
                      ),
                    ),
                  ),
                ),
                if (title != null) ...[
                  AppSpacing.gapLg,
                  Semantics(
                    header: true,
                    child: Text(title!, style: context.text.headlineSmall),
                  ),
                ],
                AppSpacing.gapLg,
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
