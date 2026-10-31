import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Centered brand spinner with an optional message.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.message, this.size = 36});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message ?? 'Loading',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: size,
              child: const CircularProgressIndicator(strokeWidth: 3.5),
            ),
            if (message != null) ...[
              AppSpacing.gapLg,
              ExcludeSemantics(
                child: Text(
                  message!,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.palette.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated placeholder block for content that is loading. Animation is
/// disabled when the platform requests reduced motion.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.borderSm,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool _animate = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (_animate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _animate
              ? Curves.easeInOut.transform(_controller.value)
              : 0;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              color: Color.lerp(
                palette.skeletonBase,
                palette.skeletonHighlight,
                t.toDouble(),
              ),
            ),
          );
        },
      ),
    );
  }
}
