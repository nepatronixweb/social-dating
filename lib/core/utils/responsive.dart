import 'package:flutter/widgets.dart';

/// Width-based layout classes.
enum ScreenSize { compact, medium, expanded }

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  static ScreenSize of(double width) {
    if (width >= expanded) return ScreenSize.expanded;
    if (width >= medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }
}

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize => Breakpoints.of(MediaQuery.sizeOf(this).width);
  bool get isCompact => screenSize == ScreenSize.compact;
}

/// Centers [child] and caps its width, so phone layouts stay readable on
/// tablets and in landscape.
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? 520),
        child: child,
      ),
    );
  }
}
