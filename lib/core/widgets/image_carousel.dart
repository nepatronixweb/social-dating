import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import 'photo_placeholder.dart';

/// Swipeable photo gallery with story-style segment indicators. Tapping the
/// left or right edge steps between photos. Fills its parent, so wrap it in an
/// `AspectRatio` or `Expanded`.
///
/// Each slot shows `images[i]` when provided, otherwise a [PhotoPlaceholder].
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({
    super.key,
    required this.photoCount,
    this.images = const [],
    this.placeholderSeed = 0,
    this.onPageChanged,
    this.semanticLabel = 'Photo',
    this.allowPageSwipe = true,
    this.showIndicator = true,
  }) : assert(photoCount > 0);

  final int photoCount;
  final List<ImageProvider?> images;
  final int placeholderSeed;
  final ValueChanged<int>? onPageChanged;
  final String semanticLabel;

  /// When false, photos change only through the edge tap zones (and
  /// accessibility actions). Use this inside a draggable card so a horizontal
  /// drag swipes the card instead of paging photos.
  final bool allowPageSwipe;

  /// Draws the built-in segment indicator. Turn off when the screen draws its
  /// own (for example in a header that sits over the photo).
  final bool showIndicator;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final target = page.clamp(0, widget.photoCount - 1);
    if (target == _page) return;
    final duration = AppMotion.resolve(context, AppMotion.normal);
    if (duration == Duration.zero) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(
        target,
        duration: duration,
        curve: AppMotion.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.semanticLabel} ${_page + 1} of ${widget.photoCount}',
      onIncrease: _page < widget.photoCount - 1 ? () => _goTo(_page + 1) : null,
      onDecrease: _page > 0 ? () => _goTo(_page - 1) : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            physics: widget.allowPageSwipe
                ? null
                : const NeverScrollableScrollPhysics(),
            itemCount: widget.photoCount,
            onPageChanged: (p) {
              setState(() => _page = p);
              widget.onPageChanged?.call(p);
            },
            itemBuilder: (context, i) {
              final image = i < widget.images.length ? widget.images[i] : null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  PhotoPlaceholder(seed: widget.placeholderSeed + i),
                  if (image != null)
                    Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                ],
              );
            },
          ),
          // Edge tap zones (left / right quarter) for stepping.
          if (widget.photoCount > 1)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final zone = constraints.maxWidth * 0.25;
                  return Row(
                    children: [
                      SizedBox(
                        width: zone,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => _goTo(_page - 1),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: zone,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => _goTo(_page + 1),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (widget.showIndicator && widget.photoCount > 1)
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < widget.photoCount; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: AnimatedContainer(
                          duration: AppMotion.resolve(context, AppMotion.fast),
                          height: AppSizes.indicatorHeight,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: i == _page ? 0.95 : 0.4,
                            ),
                            borderRadius: AppRadii.borderPill,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
