import 'package:flutter/foundation.dart';

/// Minimal logger. Logs only in non-release builds so nothing leaks to
/// production consoles. Replace the sink with a crash reporter in a later phase.
abstract final class AppLogger {
  static void debug(String message) {
    if (kReleaseMode) return;
    debugPrint('[Social Dating] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kReleaseMode) return;
    debugPrint('[Social Dating][error] $message');
    if (error != null) debugPrint('  cause: $error');
    if (stackTrace != null) debugPrint('$stackTrace');
  }
}
