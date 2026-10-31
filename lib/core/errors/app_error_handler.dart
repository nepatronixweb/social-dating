import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/app_logger.dart';

/// Installs application-wide error handling.
///
/// - Framework errors are logged (and still presented in debug builds).
/// - Uncaught async/platform errors are logged and marked handled.
/// - Build-time widget errors render a friendly fallback in release builds
///   instead of the red/grey error screen.
abstract final class AppErrorHandler {
  static void install() {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      AppLogger.error('FlutterError: ${details.exceptionAsString()}');
      if (kDebugMode) previousOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('Uncaught error', error, stack);
      return true;
    };

    final previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (details) =>
        kDebugMode ? previousBuilder(details) : const FallbackErrorWidget();
  }
}

/// Shown in place of a widget that threw during build, in release builds.
class FallbackErrorWidget extends StatelessWidget {
  const FallbackErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong displaying this section.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
