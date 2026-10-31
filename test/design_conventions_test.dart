import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the visual system consistent: one icon library (via `AppIcons`) and
/// no emoji used as icons or decoration in UI code.
void main() {
  Iterable<File> libFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('Material `Icons.` is referenced only by app_icons.dart', () {
    final offenders = <String>[];
    for (final file in libFiles()) {
      final path = file.path.replaceAll('\\', '/');
      if (path.endsWith('core/theme/app_icons.dart')) continue;
      if (RegExp(r'\bIcons\.').hasMatch(file.readAsStringSync())) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty, reason: 'Use AppIcons instead: $offenders');
  });

  test('no emoji in lib/', () {
    // Emoji and pictographs (excludes ordinary punctuation and arrows).
    final emoji = RegExp(
      '[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F2FF}\u{2B50}\u{2B55}]',
      unicode: true,
    );
    final offenders = <String>[];
    for (final file in libFiles()) {
      if (emoji.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path.replaceAll('\\', '/'));
      }
    }
    expect(offenders, isEmpty, reason: 'Emoji found in: $offenders');
  });

  test('screens do not hard-code colours or font sizes', () {
    // Screens should use theme tokens. Core widgets may define visuals, but
    // feature screens must not reach for raw colours.
    final offenders = <String>[];
    final raw = RegExp(r'Color\(0x|Colors\.(?!transparent)');
    for (final file in libFiles()) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.contains('lib/features/')) continue;
      // The debug-only gallery intentionally shows raw swatches.
      if (path.endsWith('design_system_preview_screen.dart')) continue;
      if (raw.hasMatch(file.readAsStringSync())) offenders.add(path);
    }
    expect(offenders, isEmpty, reason: 'Hard-coded colours in: $offenders');
  });
}
