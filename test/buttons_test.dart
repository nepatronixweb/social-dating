import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/theme/app_icons.dart';
import 'package:social_dating/core/theme/app_theme.dart';
import 'package:social_dating/core/widgets/app_button.dart';

import 'helpers/pump_app.dart';

void main() {
  group('AppButton variants', () {
    for (final variant in AppButtonVariant.values) {
      testWidgets('${variant.name}: shows label and fires onPressed', (
        tester,
      ) async {
        var taps = 0;
        await pumpWidgetInTheme(
          tester,
          AppButton(label: 'Save', variant: variant, onPressed: () => taps++),
        );

        expect(find.text('Save'), findsOneWidget);
        await tester.tap(find.byType(AppButton));
        await tester.pump();
        expect(taps, 1);
      });

      testWidgets('${variant.name}: disabled when onPressed is null', (
        tester,
      ) async {
        await pumpWidgetInTheme(
          tester,
          AppButton(label: 'Save', variant: variant, onPressed: null),
        );

        final semantics = tester.getSemantics(find.byType(AppButton));
        // ignore: deprecated_member_use
        expect(semantics.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
        // ignore: deprecated_member_use
        expect(semantics.hasFlag(SemanticsFlag.isEnabled), isFalse);
      });

      for (final entry in {
        'light': AppTheme.light,
        'dark': AppTheme.dark,
      }.entries) {
        testWidgets('${variant.name}: meets touch target in ${entry.key}', (
          tester,
        ) async {
          await pumpWidgetInTheme(
            tester,
            AppButton(label: 'Save', variant: variant, onPressed: () {}),
            theme: entry.value,
          );
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(AppButton)).height,
            greaterThanOrEqualTo(48),
          );
        });
      }
    }

    testWidgets('loading hides the label and ignores taps', (tester) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        AppButton(label: 'Save', isLoading: true, onPressed: () => taps++),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Save'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('renders an optional leading icon', (tester) async {
      await pumpWidgetInTheme(
        tester,
        AppButton(label: 'Copy', icon: AppIcons.copy, onPressed: () {}),
      );
      expect(find.byIcon(AppIcons.copy), findsOneWidget);
    });

    testWidgets('expand: false sizes to its content', (tester) async {
      await pumpWidgetInTheme(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: AppButton(label: 'Go', expand: false, onPressed: () {}),
        ),
      );
      expect(tester.getSize(find.byType(AppButton)).width, lessThan(200));
    });

    testWidgets('destructive uses the error colour', (tester) async {
      await pumpWidgetInTheme(
        tester,
        AppButton(
          label: 'Delete',
          variant: AppButtonVariant.destructive,
          onPressed: () {},
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppTheme.light.colorScheme.error);
    });
  });
}
