import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the rule that mock/sample data never leaks into production code.
void main() {
  // Files allowed to import `mock_*` sources.
  bool allowed(String path) {
    final p = path.replaceAll('\\', '/');
    final name = p.split('/').last;
    return name.startsWith('mock_') ||
        // The approved seams: the only production files that choose a mock.
        p.endsWith('lib/data/repositories/repository_providers.dart') ||
        p.endsWith('lib/features/auth/providers/session_provider.dart') ||
        p.endsWith(
          'features/settings/presentation/design_system_preview_screen.dart',
        );
  }

  test('only mock_* files and the debug preview import mock sources', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (allowed(entity.path)) continue;
      final imports = entity.readAsLinesSync().where(
        (l) => l.trimLeft().startsWith('import ') && l.contains('mock_'),
      );
      if (imports.isNotEmpty) offenders.add(entity.path);
    }
    expect(offenders, isEmpty, reason: 'Unexpected mock imports: $offenders');
  });

  test('the router only exposes the preview route in debug builds', () {
    final source = File('lib/core/routing/app_router.dart').readAsStringSync();
    expect(source, contains('if (kDebugMode)'));
  });

  test('no hard-coded http(s) endpoints in lib/', () {
    final urlPattern = RegExp(r'''['"]https?://''');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          urlPattern.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
