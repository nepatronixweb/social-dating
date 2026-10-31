import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/swipe.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import 'photo_placeholder.dart';

/// A card that can be dragged left (pass) or right (like).
///
/// - Only horizontal drags move the card, so vertical gestures are never
///   mistaken for a swipe.
/// - The card tilts and fades as it moves, and a LIKE / NOPE stamp fades in.
/// - Past [commitFraction] of the width (or with a fast fling) it asks
///   [onWillSwipe]. If that returns `true` the card flies off and
///   [onSwiped] is called; otherwise it springs back. [onWillSwipe] is where
///   limits, price confirmation and the profile gate belong.
/// - The same flow runs for the pass/like buttons through
///   [SwipeCardState.swipe], so the buttons are a full alternative to the
///   gesture.
///
/// Give each card a `ValueKey` of its content so a new card starts fresh.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.child,
    required this.onWillSwipe,
    required this.onSwiped,
    this.enabled = true,
    this.commitFraction = 0.3,
  });

  final Widget child;
  final Future<bool> Function(SwipeDirection direction) onWillSwipe;
  final ValueChanged<SwipeDirection> onSwiped;
  final bool enabled;

  /// Fraction of the card width a drag must pass to count as a swipe.
  final double commitFraction;

  @override
  State<SwipeCard> createState() => SwipeCardState();
}

class SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  static const double _maxTilt = 0.30; // radians at one full card width
  static const double _flingVelocity = 900; // px/s

  late final AnimationController _controller = AnimationController(vsync: this);

  double _width = 1;
  double _dragDx = 0;
  double _from = 0;
  double _to = 0;
  Curve _curve = Curves.linear;
  bool _animating = false;

  /// True from the moment a swipe is requested until the card is gone or has
  /// snapped back. Ignores further input meanwhile.
  bool _busy = false;

  /// Current horizontal offset in logical pixels.
  double get offset => _animating
      ? _from + (_to - _from) * _curve.transform(_controller.value)
      : _dragDx;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateTo(
    double target, {
    required Duration duration,
    required Curve curve,
  }) async {
    _from = offset;
    _to = target;
    _curve = curve;
    _animating = true;
    _controller.duration = AppMotion.resolve(context, duration);
    _controller.value = 0;
    await _controller.forward();
    if (!mounted) return;
    setState(() {
      _dragDx = target;
      _animating = false;
    });
  }

  /// Runs the full swipe flow as if the card had been dragged all the way.
  Future<void> swipe(SwipeDirection direction) async {
    if (_busy || !widget.enabled) return;
    _busy = true;
    final approved = await widget.onWillSwipe(direction);
    if (!mounted) return;
    if (!approved) {
      await _animateTo(
        0,
        duration: AppMotion.normal,
        curve: Curves.easeOutBack,
      );
      if (mounted) _busy = false;
      return;
    }
    final sign = direction == SwipeDirection.right ? 1.0 : -1.0;
    await _animateTo(
      sign * _width * 1.5,
      duration: AppMotion.normal,
      curve: AppMotion.exit,
    );
    if (!mounted) return;
    widget.onSwiped(direction);
  }

  void _onDragStart(DragStartDetails details) {
    if (_busy || !widget.enabled) return;
    setState(() {
      _animating = false;
      _dragDx = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_busy || !widget.enabled) return;
    setState(() => _dragDx += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_busy || !widget.enabled) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final threshold = _width * widget.commitFraction;
    SwipeDirection? direction;
    if (_dragDx > threshold || (velocity > _flingVelocity && _dragDx > 24)) {
      direction = SwipeDirection.right;
    } else if (_dragDx < -threshold ||
        (velocity < -_flingVelocity && _dragDx < -24)) {
      direction = SwipeDirection.left;
    }
    if (direction == null) {
      _busy = true;
      _animateTo(
        0,
        duration: AppMotion.normal,
        curve: Curves.easeOutBack,
      ).whenComplete(() => _busy = false);
    } else {
      swipe(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400;
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) {
              final dx = offset;
              final progress = (dx / (_width * widget.commitFraction)).clamp(
                -1.0,
                1.0,
              );
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(
                  angle: (dx / _width) * _maxTilt,
                  alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: 1 - 0.3 * progress.abs().clamp(0.0, 1.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child!,
                        if (progress != 0)
                          SwipeDirectionOverlay(
                            direction: progress > 0
                                ? SwipeDirection.right
                                : SwipeDirection.left,
                            strength: progress.abs(),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// The LIKE / NOPE stamp and tint shown over a card while it is dragged.
/// Meaning is carried by the icon and word, not by colour alone. Not announced
/// by screen readers (the pass/like buttons are the accessible route).
class SwipeDirectionOverlay extends StatelessWidget {
  const SwipeDirectionOverlay({
    super.key,
    required this.direction,
    required this.strength,
  });

  final SwipeDirection direction;

  /// 0 (invisible) to 1 (fully shown).
  final double strength;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final isLike = direction == SwipeDirection.right;
    final accent = isLike ? palette.success : colors.error;
    final opacity = strength.clamp(0.0, 1.0);

    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: ClipRRect(
            borderRadius: AppRadii.borderXl,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: accent.withValues(alpha: 0.18)),
                Positioned(
                  top: AppSpacing.xxl,
                  left: isLike ? AppSpacing.xl : null,
                  right: isLike ? null : AppSpacing.xl,
                  child: Transform.rotate(
                    angle: isLike ? -0.21 : 0.21,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.9),
                        borderRadius: AppRadii.borderMd,
                        border: Border.all(color: accent, width: 3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLike ? AppIcons.heart : AppIcons.pass,
                              color: accent,
                              size: AppSizes.iconLg,
                            ),
                            AppSpacing.gapSm,
                            Text(
                              isLike ? 'LIKE' : 'NOPE',
                              style: context.text.titleLarge?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

/// A plain, text-free card shown behind the top card so the next profile is
/// hinted at without duplicating its content. [lift] (0 to 1) grows it
/// slightly as the top card is dragged away.
class SwipeCardBackdrop extends StatelessWidget {
  const SwipeCardBackdrop({super.key, this.seed = 0, this.lift = 0});

  final int seed;
  final double lift;

  @override
  Widget build(BuildContext context) {
    final scale = 0.94 + 0.06 * math.min(1.0, math.max(0.0, lift));
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Transform.scale(
          scale: scale,
          child: ClipRRect(
            borderRadius: AppRadii.borderXl,
            child: PhotoPlaceholder(seed: seed),
          ),
        ),
      ),
    );
  }
}
