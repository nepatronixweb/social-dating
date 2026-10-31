import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/core/utils/age.dart';
import 'package:social_dating/core/widgets/acknowledgement_tile.dart';
import 'package:social_dating/core/widgets/date_of_birth_input.dart';
import 'package:social_dating/core/widgets/development_notice_banner.dart';
import 'package:social_dating/core/widgets/failure_banner.dart';
import 'package:social_dating/core/widgets/auth_step_indicator.dart';
import 'package:social_dating/core/widgets/onboarding_progress.dart';
import 'package:social_dating/core/widgets/otp_input.dart';
import 'package:social_dating/core/widgets/phone_number_field.dart';
import 'package:social_dating/core/widgets/resend_code_button.dart';
import 'package:social_dating/data/models/country.dart';

import 'helpers/pump_app.dart';

void main() {
  group('OtpInput', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Finder field() => find.descendant(
      of: find.byType(OtpInput),
      matching: find.byType(TextField),
    );

    Future<void> pumpOtp(
      WidgetTester tester, {
      String? errorText,
      bool enabled = true,
      ValueChanged<String>? onCompleted,
      ValueChanged<String>? onChanged,
    }) {
      return pumpWidgetInTheme(
        tester,
        Padding(
          padding: const EdgeInsets.all(24),
          child: OtpInput(
            controller: controller,
            errorText: errorText,
            enabled: enabled,
            onCompleted: onCompleted,
            onChanged: onChanged,
          ),
        ),
      );
    }

    testWidgets('shows one box per digit as they are typed', (tester) async {
      await pumpOtp(tester);
      await tester.enterText(field(), '123');
      await tester.pump();

      for (final digit in ['1', '2', '3']) {
        expect(find.text(digit), findsOneWidget);
      }
      expect(find.text('4'), findsNothing);
    });

    testWidgets('accepts digits only and never more than six', (tester) async {
      await pumpOtp(tester);

      await tester.enterText(field(), 'a1b2-3');
      await tester.pump();
      expect(controller.text, '123');

      await tester.enterText(field(), '123456789');
      await tester.pump();
      expect(controller.text, '123456');
    });

    testWidgets('uses the numeric keyboard and one-time-code autofill', (
      tester,
    ) async {
      await pumpOtp(tester);
      final textField = tester.widget<TextField>(field());
      expect(textField.keyboardType, TextInputType.number);
      expect(textField.autofillHints, contains(AutofillHints.oneTimeCode));
    });

    testWidgets('reports changes and completes only on the last digit', (
      tester,
    ) async {
      final changes = <String>[];
      String? completed;
      await pumpOtp(
        tester,
        onChanged: changes.add,
        onCompleted: (v) => completed = v,
      );

      await tester.enterText(field(), '12345');
      await tester.pump();
      expect(completed, isNull);

      await tester.enterText(field(), '123456');
      await tester.pump();
      expect(completed, '123456');
      expect(changes, ['12345', '123456']);
    });

    testWidgets('pasting a whole code fills every box', (tester) async {
      await pumpOtp(tester);
      await tester.enterText(field(), '482913');
      await tester.pump();
      for (final digit in ['4', '8', '2', '9', '1', '3']) {
        expect(find.text(digit), findsOneWidget);
      }
    });

    testWidgets('shows an error in words, not only colour', (tester) async {
      await pumpOtp(tester, errorText: 'That code isn\'t right.');
      expect(find.text('That code isn\'t right.'), findsOneWidget);
    });

    testWidgets('can be disabled while verifying', (tester) async {
      await pumpOtp(tester, enabled: false);
      expect(tester.widget<TextField>(field()).enabled, isFalse);
    });

    testWidgets('exposes a labelled group to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOtp(tester);
      expect(find.bySemanticsLabel(RegExp('Verification code')), findsWidgets);
      handle.dispose();
    });
  });

  group('ResendCodeButton', () {
    Future<void> pumpButton(
      WidgetTester tester, {
      required Future<bool> Function() onResend,
      Duration cooldown = const Duration(seconds: 5),
      bool readyNow = false,
    }) {
      return pumpWidgetInTheme(
        tester,
        ResendCodeButton(
          onResend: onResend,
          cooldown: cooldown,
          readyNow: readyNow,
        ),
      );
    }

    testWidgets('counts down, then offers a resend button', (tester) async {
      await pumpButton(tester, onResend: () async => true);

      expect(find.text('Resend code in 0:05'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Resend code'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Resend code in 0:03'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.widgetWithText(TextButton, 'Resend code'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsNothing);
    });

    testWidgets('a minute-long cooldown shows minutes and seconds', (
      tester,
    ) async {
      await pumpButton(
        tester,
        onResend: () async => true,
        cooldown: const Duration(seconds: 75),
      );
      expect(find.text('Resend code in 1:15'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('resending restarts the countdown', (tester) async {
      var sent = 0;
      await pumpButton(
        tester,
        onResend: () async {
          sent++;
          return true;
        },
      );
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump();

      expect(sent, 1);
      expect(find.text('Resend code in 0:05'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failed resend leaves the button available', (tester) async {
      var sent = 0;
      await pumpButton(
        tester,
        onResend: () async {
          sent++;
          return false;
        },
      );
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump();

      expect(sent, 1);
      expect(find.widgetWithText(TextButton, 'Resend code'), findsOneWidget);
    });

    testWidgets('shows progress while a resend is in flight', (tester) async {
      final completer = Completer<bool>();
      await pumpButton(tester, onResend: () => completer.future);
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Resend code'), findsNothing);

      completer.complete(true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('readyNow skips the wait (expired code)', (tester) async {
      await pumpButton(tester, onResend: () async => true, readyNow: true);
      expect(find.widgetWithText(TextButton, 'Resend code'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('OnboardingProgress', () {
    testWidgets('states the step and its name', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const OnboardingProgress(step: 2, label: 'Code'),
      );
      expect(find.text('Step 2 of 5 · Code'), findsOneWidget);
    });

    testWidgets('complete state', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const OnboardingProgress(step: 5, complete: true),
      );
      expect(find.text('Setup complete'), findsOneWidget);
    });

    testWidgets('is announced with its progress', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWidgetInTheme(
        tester,
        const OnboardingProgress(step: 3, label: 'Terms'),
      );
      expect(
        tester.getSemantics(find.byType(OnboardingProgress)),
        matchesSemantics(label: 'Step 3 of 5 · Terms', value: '60 percent'),
      );
      handle.dispose();
    });

    test('rejects a step outside the range', () {
      expect(() => OnboardingProgress(step: 0), throwsAssertionError);
      expect(() => OnboardingProgress(step: 6), throwsAssertionError);
    });
  });

  group('AuthStepIndicator', () {
    testWidgets('shows the cinematic step caption', (tester) async {
      await pumpWidgetInTheme(tester, const AuthStepIndicator(step: 1));
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
    });

    test('rejects a step outside the range', () {
      expect(() => AuthStepIndicator(step: 0), throwsAssertionError);
      expect(() => AuthStepIndicator(step: 4), throwsAssertionError);
    });
  });

  group('DateOfBirthInput', () {
    BirthDateParse? last;

    Future<void> pumpDob(WidgetTester tester) {
      last = null;
      return pumpWidgetInTheme(
        tester,
        SingleChildScrollView(
          child: DateOfBirthInput(
            today: testNow,
            onChanged: (parse) => last = parse,
          ),
        ),
      );
    }

    Finder part(String label) => find.widgetWithText(TextFormField, label);

    Future<void> enter(
      WidgetTester tester,
      String d,
      String m,
      String y,
    ) async {
      await tester.enterText(part('Day'), d);
      await tester.enterText(part('Month'), m);
      await tester.enterText(part('Year'), y);
      await tester.pump();
    }

    testWidgets('uses numeric keyboards and digit-only fields', (tester) async {
      await pumpDob(tester);
      for (final label in ['Day', 'Month', 'Year']) {
        final field = tester.widget<TextField>(
          find.descendant(of: part(label), matching: find.byType(TextField)),
        );
        expect(field.keyboardType, TextInputType.number, reason: label);
      }

      await tester.enterText(part('Day'), 'a1b');
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a complete real date is reported as valid', (tester) async {
      await pumpDob(tester);
      await enter(tester, '14', '10', '2008');
      expect(last!.isValid, isTrue);
      expect(last!.date, DateTime(2008, 10, 14));
    });

    testWidgets('incomplete input says nothing', (tester) async {
      await pumpDob(tester);
      await tester.enterText(part('Day'), '14');
      await tester.pump();
      expect(last!.isValid, isFalse);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });

    testWidgets('explains an impossible date', (tester) async {
      await pumpDob(tester);
      await enter(tester, '31', '02', '1995');
      expect(last!.isValid, isFalse);
      expect(
        find.text('That date doesn\'t exist. Check the day.'),
        findsOneWidget,
      );
    });

    testWidgets('explains a future date', (tester) async {
      await pumpDob(tester);
      await enter(tester, '01', '01', '2030');
      expect(
        find.text('Your birth date can\'t be in the future.'),
        findsOneWidget,
      );
    });

    testWidgets('moves on to the next part when one is full', (tester) async {
      await pumpDob(tester);
      await tester.enterText(part('Day'), '14');
      await tester.pump();

      final month = tester.widget<EditableText>(
        find.descendant(of: part('Month'), matching: find.byType(EditableText)),
      );
      expect(month.focusNode.hasFocus, isTrue);
    });
  });

  group('PhoneNumberField and CountrySelector', () {
    Future<void> pumpField(
      WidgetTester tester, {
      ValueChanged<Country>? onCountry,
      Country country = Country.nepal,
      String? errorText,
    }) {
      usePhoneScreen(tester);
      var current = country;
      return pumpWidgetInTheme(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(24),
            child: PhoneNumberField(
              country: current,
              errorText: errorText,
              onCountryChanged: (c) {
                onCountry?.call(c);
                setState(() => current = c);
              },
            ),
          ),
        ),
      );
    }

    testWidgets('shows Nepal (+977) and its example number', (tester) async {
      await pumpField(tester);
      expect(find.text('NP'), findsOneWidget);
      expect(find.text('+977'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget, reason: 'hint');
      expect(
        tester.widget<TextField>(find.byType(TextField)).keyboardType,
        TextInputType.phone,
      );
    });

    testWidgets('shows a supplied error', (tester) async {
      await pumpField(tester, errorText: 'That number looks too short');
      expect(find.text('That number looks too short'), findsOneWidget);
    });

    testWidgets('groups digits as they are typed', (tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(TextField), '9841234567');
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '984 123 4567',
      );
    });

    testWidgets('opens a country list and picks another country', (
      tester,
    ) async {
      Country? picked;
      await pumpField(tester, onCountry: (c) => picked = c);

      await tester.tap(find.text('+977'));
      await tester.pumpAndSettle();
      expect(find.text('Select country'), findsOneWidget);
      expect(find.text('Nepal'), findsOneWidget);
      expect(find.text('India'), findsOneWidget);

      await tester.tap(find.text('India'));
      await tester.pumpAndSettle();

      expect(picked?.isoCode, 'IN');
      expect(find.text('IN'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Select country'), findsNothing);
    });

    testWidgets('the country list can be searched', (tester) async {
      await pumpField(tester);
      await tester.tap(find.text('+977'));
      await tester.pumpAndSettle();

      final search = find.widgetWithText(TextFormField, 'Search country');
      await tester.enterText(search, 'ind');
      await tester.pump();
      expect(find.text('India'), findsOneWidget);
      expect(find.text('Nepal'), findsNothing);

      await tester.enterText(search, 'zzz');
      await tester.pump();
      expect(find.textContaining('No countries match'), findsOneWidget);

      await tester.enterText(search, '+91');
      await tester.pump();
      expect(find.text('India'), findsOneWidget);
    });
  });

  group('AcknowledgementTile', () {
    testWidgets('tapping anywhere on the row toggles it', (tester) async {
      bool? changed;
      await pumpWidgetInTheme(
        tester,
        AcknowledgementTile(
          value: false,
          onChanged: (v) => changed = v,
          title: 'I agree',
        ),
      );
      await tester.tap(find.text('I agree'));
      expect(changed, isTrue);
    });

    testWidgets('a checked tile offers to uncheck', (tester) async {
      bool? changed;
      await pumpWidgetInTheme(
        tester,
        AcknowledgementTile(
          value: true,
          onChanged: (v) => changed = v,
          title: 'I agree',
        ),
      );
      await tester.tap(find.text('I agree'));
      expect(changed, isFalse);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('does nothing when disabled', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const AcknowledgementTile(
          value: false,
          onChanged: null,
          title: 'I agree',
        ),
      );
      await tester.tap(find.text('I agree'));
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('keeps a trailing action tappable on its own', (tester) async {
      var toggled = false;
      var read = false;
      await pumpWidgetInTheme(
        tester,
        AcknowledgementTile(
          value: false,
          onChanged: (_) => toggled = true,
          title: 'I agree',
          trailing: TextButton(
            onPressed: () => read = true,
            child: const Text('Read'),
          ),
        ),
      );
      await tester.tap(find.text('Read'));
      expect(read, isTrue);
      expect(toggled, isFalse);
    });
  });

  group('FailureBanner', () {
    Future<void> pumpBanner(
      WidgetTester tester,
      AppFailure failure,
      VoidCallback onRetry,
    ) {
      return pumpWidgetInTheme(
        tester,
        FailureBanner(failure: failure, onRetry: onRetry),
      );
    }

    testWidgets('network errors can be retried', (tester) async {
      var retried = 0;
      await pumpBanner(tester, const NetworkFailure(), () => retried++);

      expect(find.text('You\'re offline'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('generic sign-in failures can be retried', (tester) async {
      await pumpBanner(tester, const AuthenticationFailure(), () {});
      expect(find.text('Sign-in failed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('wrong and expired codes are not "retried"', (tester) async {
      for (final failure in [
        const InvalidCodeFailure(),
        const CodeExpiredFailure(),
      ]) {
        await pumpBanner(tester, failure, () {});
        expect(find.text('Try again'), findsNothing, reason: '$failure');
      }
    });
  });

  group('DevelopmentNoticeBanner', () {
    testWidgets('shows the notice it is given', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const DevelopmentNoticeBanner(
          notice: 'Development mock: no SMS is sent.',
        ),
      );
      expect(find.text('Development mock: no SMS is sent.'), findsOneWidget);
    });

    testWidgets('renders nothing when verification is real', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const DevelopmentNoticeBanner(notice: null),
      );
      expect(find.byType(Text), findsNothing);
    });
  });
}
