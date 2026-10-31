import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/errors/app_error_handler.dart';

void main() {
  group('AppErrorHandler', () {
    late FlutterExceptionHandler? originalOnError;
    late ErrorWidgetBuilder originalBuilder;
    late ErrorCallback? originalPlatformOnError;

    setUp(() {
      originalOnError = FlutterError.onError;
      originalBuilder = ErrorWidget.builder;
      originalPlatformOnError = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
      ErrorWidget.builder = originalBuilder;
      PlatformDispatcher.instance.onError = originalPlatformOnError;
    });

    test('install() replaces the framework and platform handlers', () {
      AppErrorHandler.install();

      expect(FlutterError.onError, isNot(same(originalOnError)));
      expect(PlatformDispatcher.instance.onError, isNotNull);
      // Uncaught async errors are reported as handled (the app keeps running).
      expect(
        PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.empty),
        isTrue,
      );
    });

    test('framework errors are forwarded to the previous handler in debug', () {
      FlutterErrorDetails? seen;
      FlutterError.onError = (d) => seen = d;
      AppErrorHandler.install();

      FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));
      expect(seen, isNotNull);
    });

    testWidgets('fallback widget shows a friendly message, no internals', (
      tester,
    ) async {
      await tester.pumpWidget(const FallbackErrorWidget());
      expect(
        find.text('Something went wrong displaying this section.'),
        findsOneWidget,
      );
    });
  });
}
