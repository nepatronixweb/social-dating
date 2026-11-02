import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/brand_atmosphere.dart';
import '../../../core/widgets/brand_mark.dart';

/// Branded splash. Does no network or disk work; it simply holds the brand
/// for a moment and then moves to the welcome screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow * 2,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    _timer = Timer(
      reduceMotion
          ? const Duration(milliseconds: 600)
          : AppConstants.splashDuration,
      _goNext,
    );
  }

  void _goNext() {
    if (!mounted) return;
    context.go(AppRoutes.welcome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.7, curve: AppMotion.standard),
    );
    final scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.emphasized),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.palette.pageBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const BrandAtmosphere(style: BrandAtmosphereStyle.waves),
            SafeArea(
              child: FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: scale,
                  child: Padding(
                    padding: AppSpacing.pagePadding.copyWith(
                      top: AppSpacing.xl,
                      bottom: AppSpacing.xxl,
                    ),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        const BrandMark(size: 128, glow: false),
                        const Spacer(flex: 2),
                        const _SplashDots(count: 5, index: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative pager matching the splash mock. Not interactive: this screen
/// is timed, not a carousel.
class _SplashDots extends StatelessWidget {
  const _SplashDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Introduction, page ${index + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              _Dot(active: i == index),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.colors.primary : context.palette.outlineSoft;
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      width: active ? 18 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.borderPill,
      ),
    );
  }
}
