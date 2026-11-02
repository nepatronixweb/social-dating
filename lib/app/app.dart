import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/theme_context.dart';
import '../features/ops/providers/client_config_provider.dart';
import '../features/settings/providers/theme_mode_provider.dart';
import '../features/settings/providers/user_preferences_provider.dart';

/// Root widget. [router] is overridable so tests can start at any location.
class SocialDatingApp extends ConsumerWidget {
  const SocialDatingApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final clientConfig = ref.watch(clientAppConfigProvider);

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
        final config = clientConfig.asData?.value;
        final maintenance = config?.maintenanceMode == true;
        final blocked = config != null && clientBuildBlocked(config);
        final bannerOn = config?.bannerEnabled == true &&
            (config?.bannerTitle?.isNotEmpty == true ||
                config?.bannerBody?.isNotEmpty == true);

        Widget content = child ?? const SizedBox.shrink();
        if (maintenance || blocked) {
          content = _ClientOpsGate(
            title: maintenance ? 'Under maintenance' : 'Update required',
            body: maintenance
                ? 'Social Dating is temporarily unavailable. Try again later.'
                : 'Install a newer build to continue.',
          );
        } else if (bannerOn) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: context.palette.surfaceMuted,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (config!.bannerTitle != null &&
                            config.bannerTitle!.isNotEmpty)
                          Text(
                            config.bannerTitle!,
                            style: context.text.titleSmall,
                          ),
                        if (config.bannerBody != null &&
                            config.bannerBody!.isNotEmpty)
                          Text(
                            config.bannerBody!,
                            style: context.text.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          );
        }

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
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _ClientOpsGate extends StatelessWidget {
  const _ClientOpsGate({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: context.text.headlineSmall),
              const SizedBox(height: 12),
              Text(body, style: context.text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
