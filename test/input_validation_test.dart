import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/utils/phone_formatter.dart';
import 'package:social_dating/core/utils/validators.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/discovery/presentation/discovery_screen.dart';
import 'package:social_dating/features/onboarding/presentation/signup_gender_screen.dart';
import 'package:social_dating/features/onboarding/presentation/signup_name_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  group('Validators', () {
    test('phone', () {
      expect(Validators.phone(null), 'Enter your phone number');
      expect(Validators.phone('  '), 'Enter your phone number');
      expect(Validators.phone('12345'), 'That number looks too short');
      expect(Validators.phone('555 123 4567'), isNull);
      expect(Validators.phone('+1 555 123 4567'), isNull);
      expect(Validators.phone('1' * 16), 'That number looks too long');
    });

    test('verification code', () {
      expect(Validators.verificationCode(''), 'Enter the 6-digit code');
      expect(Validators.verificationCode('123'), 'The code has 6 digits');
      expect(Validators.verificationCode('1234567'), 'The code has 6 digits');
      expect(Validators.verificationCode('123456'), isNull);
    });

    test('display name', () {
      expect(Validators.displayName(''), 'Enter your full name');
      expect(Validators.displayName('A'), 'Use at least 2 characters');
      expect(Validators.displayName('Al1'), 'Use letters only');
      expect(Validators.displayName('A' * 31), 'Keep it under 30 characters');
      expect(Validators.displayName('Anne-Marie'), isNull);
      expect(Validators.displayName('José'), isNull);
    });

    test('age enforces the 18+ rule', () {
      expect(Validators.age(''), 'Enter your age');
      expect(Validators.age('ab'), 'Enter a number');
      expect(Validators.age('17'), 'You must be 18 or older');
      expect(Validators.age('18'), isNull);
      expect(Validators.age('99'), isNull);
      expect(Validators.age('100'), 'Enter a valid age');
    });

    test('bio length', () {
      expect(Validators.bio(null), isNull);
      expect(Validators.bio('a' * 300), isNull);
      expect(Validators.bio('a' * 301), isNotNull);
    });

    test('required', () {
      expect(Validators.required(' ', label: 'Name'), 'Name is required');
      expect(Validators.required('x'), isNull);
    });
  });

  group('PhoneNumberFormatter', () {
    test('groups digits with spaces', () {
      expect(PhoneNumberFormatter.format('5551234567'), '555 123 4567');
      expect(PhoneNumberFormatter.format('555'), '555');
      expect(PhoneNumberFormatter.format('5551'), '555 1');
    });

    test('keeps a leading plus and drops other characters', () {
      expect(PhoneNumberFormatter.format('+15551234567'), startsWith('+'));
      expect(PhoneNumberFormatter.format('(555) 123-4567'), '555 123 4567');
    });

    test('never exceeds 15 digits', () {
      final formatted = PhoneNumberFormatter.format('1' * 25);
      expect(PhoneNumberFormatter.digitsOf(formatted).length, 15);
    });

    test('normalize returns digits with an optional plus', () {
      expect(
        PhoneNumberFormatter.normalize('+1 (555) 123-4567'),
        '+15551234567',
      );
      expect(PhoneNumberFormatter.normalize('555-123'), '555123');
      expect(PhoneNumberFormatter.normalize(''), '');
    });

    test('ignores letters while typing', () {
      const formatter = PhoneNumberFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'abc555',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(result.text, '555');
      expect(result.selection.baseOffset, 3);
    });

    test('keeps the caret after the digit being edited', () {
      const formatter = PhoneNumberFormatter();
      // User types a "5" after the third digit of "555 123 4567".
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '555 123 4567',
          selection: TextSelection.collapsed(offset: 3),
        ),
        const TextEditingValue(
          text: '5555 123 4567',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(result.text, '555 512 3456 7');
      // After the 4th digit, i.e. after "555 5".
      expect(result.selection.baseOffset, 5);
    });
  });

  group('signup gender and name', () {
    testWidgets('gender is required before continuing', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: '/onboarding/gender',
        session: AuthStatus.needsGender,
      );
      await pumpFrames(tester);

      expect(find.byType(SignupGenderScreen), findsOneWidget);
      expect(find.text('Step 1 of 2 · Gender'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('LGBTQ+'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Select who you are.'), findsOneWidget);
      expect(find.byType(SignupGenderScreen), findsOneWidget);
    });

    testWidgets('an empty name lists what is missing', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: '/profile-completion',
        session: AuthStatus.incompleteProfile,
        gender: ProfileGender.female,
      );
      await pumpFrames(tester);

      expect(find.byType(SignupNameScreen), findsOneWidget);
      expect(find.text('Step 2 of 2 · Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Age'), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.byType(SignupNameScreen), findsOneWidget);
    });

    testWidgets('a valid name opens the app', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: '/profile-completion',
        session: AuthStatus.incompleteProfile,
        gender: ProfileGender.female,
      );
      await pumpFrames(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Sam',
      );
      await tester.tap(find.text('Continue'));
      await pumpFrames(tester);

      final session = containerOf(tester).read(sessionProvider);
      expect(session.status, AuthStatus.loggedIn);
      expect(session.displayName, 'Sam');
      expect(find.byType(DiscoveryScreen), findsOneWidget);
    });
  });
}
