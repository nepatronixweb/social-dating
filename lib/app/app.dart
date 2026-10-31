import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/providers/theme_mode_provider.dart';
import '../features/settings/providers/user_preferences_provider.dart';

/// Root widget. [router] is overridable so tests can start at any location.
class SocialDatingApp extends ConsumerWidget {
  const SocialDatingApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router ?? ref.watch(routerProvider),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final prefs = ref.watch(userPreferencesProvider);
        final media = MediaQuery.of(context);
        // Respect the user's text size, but cap at 2x so layouts stay usable.
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || prefs.reduceMotion,
            boldText: media.boldText || prefs.boldText,
          ),
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.85,
            maxScaleFactor: 2.0,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: isDark
                  ? SystemUiOverlayStyle.light.copyWith(
                      statusBarColor: Colors.transparent,
                    )
                  : SystemUiOverlayStyle.dark.copyWith(
                      statusBarColor: Colors.transparent,
                    ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
