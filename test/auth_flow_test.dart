import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_dating/core/constants/app_constants.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/core/widgets/brand_mark.dart';
import 'package:social_dating/core/widgets/otp_input.dart';
import 'package:social_dating/data/models/account_state.dart';
import 'package:social_dating/data/repositories/mock_auth_repository.dart';
import 'package:social_dating/features/auth/presentation/phone_screen.dart';
import 'package:social_dating/features/auth/presentation/session_expired_screen.dart';
import 'package:social_dating/features/auth/presentation/verify_screen.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/discovery/presentation/discovery_screen.dart';
import 'package:social_dating/features/legal/presentation/legal_document_screen.dart';
import 'package:social_dating/features/onboarding/presentation/birth_date_screen.dart';
import 'package:social_dating/features/onboarding/presentation/ineligible_screen.dart';
import 'package:social_dating/features/onboarding/presentation/onboarding_complete_screen.dart';
import 'package:social_dating/features/onboarding/presentation/signup_gender_screen.dart';
import 'package:social_dating/features/onboarding/presentation/signup_name_screen.dart';
import 'package:social_dating/features/onboarding/presentation/terms_screen.dart';
import 'package:social_dating/features/onboarding/presentation/welcome_screen.dart';

import 'helpers/pump_app.dart';

const _wrongCode = 'That code isn\'t right. Check it and try again.';
const _expiredCode = 'That code has expired. Request a new one.';

/// A mock repository whose terms step fails the first time, to test retry.
class _FlakyAuthRepository extends MockAuthRepository {
  _FlakyAuthRepository({required super.now}) : super(latency: Duration.zero);

  bool failNextTerms = true;

  @override
  Future<AccountState> acceptTerms(String accountId) async {
    if (failNextTerms) {
      failNextTerms = false;
      throw const NetworkFailure();
    }
    return super.acceptTerms(accountId);
  }
}

/// A mock repository with visible latency, to observe loading states.
MockAuthRepository _slowRepository(
  DateTime Function() now,
  AccountState? saved,
) => MockAuthRepository(
  latency: const Duration(milliseconds: 500),
  now: now,
  seed: [?saved],
);

Finder _phoneField() => find.byType(TextFormField);
Finder _otpField() => find.descendant(
  of: find.byType(OtpInput),
  matching: find.byType(TextField),
);
Finder _button(String label) => find.widgetWithText(AppButton, label);
AppButton _appButton(WidgetTester tester, String label) =>
    tester.widget<AppButton>(_button(label));
bool _enabled(WidgetTester tester, String label) =>
    _appButton(tester, label).onPressed != null;

Future<GoRouter> _open(
  WidgetTester tester,
  String location, {
  AuthStatus? session = AuthStatus.loggedOut,
  Map<String, Object> prefs = const {},
  MockAuthRepository Function(DateTime Function() now, AccountState? saved)?
  authRepository,
  DateTime Function()? clock,
}) async {
  usePhoneScreen(tester);
  final router = await pumpApp(
    tester,
    location: location,
    session: session,
    prefs: prefs,
    authRepository: authRepository,
    clock: clock,
  );
  await pumpFrames(tester);
  return router;
}

Future<void> _enterPhone(WidgetTester tester, String digits) async {
  await tester.enterText(_phoneField(), digits);
  await tester.pump();
}

Future<void> _enterDate(
  WidgetTester tester,
  String day,
  String month,
  String year,
) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Day'), day);
  await tester.enterText(find.widgetWithText(TextFormField, 'Month'), month);
  await tester.enterText(find.widgetWithText(TextFormField, 'Year'), year);
  await tester.pump();
}

void main() {
  group('welcome screen', () {
    testWidgets('shows logo, positioning and both calls to action', (
      tester,
    ) async {
      await _open(tester, AppRoutes.welcome);

      expect(find.byType(BrandMark), findsWidgets);
      expect(find.text(AppConstants.appName), findsNothing);
      expect(find.textContaining('Dating with'), findsOneWidget);
      expect(find.textContaining('intention.'), findsOneWidget);
      expect(find.textContaining('real conversations'), findsOneWidget);
      expect(_button('Create account'), findsNothing);
      expect(_button('Log in'), findsOneWidget);
    });

    testWidgets('links to the Terms and Privacy Policy', (tester) async {
      await _open(tester, AppRoutes.welcome);

      await tester.tap(find.text('Terms of Service'));
      await pumpFrames(tester);
      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.textContaining('Terms'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await pumpFrames(tester);
      await tester.tap(find.text('Privacy Policy'));
      await pumpFrames(tester);
      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.text('What we collect'), findsOneWidget);
    });

    testWidgets('"Log in" opens the phone screen', (tester) async {
      final router = await _open(tester, AppRoutes.welcome);

      await tester.tap(_button('Log in'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.authPhone);
      expect(find.byType(PhoneScreen), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsNothing);
    });

    testWidgets('a new number goes code then gender then name', (tester) async {
      final router = await _open(tester, AppRoutes.welcome);

      await tester.tap(_button('Log in'));
      await pumpFrames(tester);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsNothing);

      await _enterPhone(tester, '9841234567');
      await tester.tap(_button('Send code'));
      await pumpFrames(tester);
      expect(find.byType(VerifyScreen), findsOneWidget);
      expect(find.text('Create account'), findsWidgets);
      expect(_button('Verify'), findsOneWidget);
      expect(_button('Log in'), findsNothing);

      await tester.enterText(_otpField(), '123456');
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.onboardingGender);
      expect(find.byType(SignupGenderScreen), findsOneWidget);
      expect(find.byType(DiscoveryScreen), findsNothing);
      expect(
        containerOf(tester).read(sessionProvider).status,
        AuthStatus.needsGender,
      );
    });

    testWidgets(
      'a number that already has an account opens the app on the next code',
      (tester) async {
        final router = await _open(tester, AppRoutes.authPhone);

        await _enterPhone(tester, '9841234567');
        await tester.tap(_button('Send code'));
        await pumpFrames(tester);
        await tester.enterText(_otpField(), '123456');
        await pumpFrames(tester);
        expect(find.byType(SignupGenderScreen), findsOneWidget);

        await tester.tap(find.text('Sign out'));
        await pumpFrames(tester);
        expect(find.byType(WelcomeScreen), findsOneWidget);

        await tester.tap(_button('Log in'));
        await pumpFrames(tester);
        await _enterPhone(tester, '9841234567');
        await tester.tap(_button('Send code'));
        await pumpFrames(tester);
        await tester.enterText(_otpField(), '123456');
        await pumpFrames(tester);

        expect(currentPath(router), AppRoutes.discover);
        expect(find.byType(DiscoveryScreen), findsOneWidget);
        expect(find.byType(SignupNameScreen), findsNothing);
        expect(
          containerOf(tester).read(sessionProvider).status,
          AuthStatus.loggedIn,
        );
      },
    );
  });

  group('phone screen', () {
    testWidgets('defaults to Nepal (+977) with a phone keyboard', (
      tester,
    ) async {
      await _open(tester, AppRoutes.authPhone);

      expect(find.text('NP'), findsOneWidget);
      expect(find.text('+977'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).keyboardType,
        TextInputType.phone,
      );
    });

    testWidgets('submit is disabled until the number is valid', (tester) async {
      await _open(tester, AppRoutes.authPhone);
      expect(_enabled(tester, 'Send code'), isFalse);

      await _enterPhone(tester, '98412');
      expect(_enabled(tester, 'Send code'), isFalse);

      await _enterPhone(tester, '9841234567');
      expect(_enabled(tester, 'Send code'), isTrue);

      await _enterPhone(tester, '984123');
      expect(_enabled(tester, 'Send code'), isFalse);
    });

    testWidgets('valid numbers: formats and enables submit', (tester) async {
      for (final number in ['9841234567', '984 123 4567', '9612345678']) {
        await _open(tester, AppRoutes.authPhone);
        await _enterPhone(tester, number);

        expect(_enabled(tester, 'Send code'), isTrue, reason: number);
        expect(find.textContaining('Nepal mobile'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('formats the number as it is typed', (tester) async {
      await _open(tester, AppRoutes.authPhone);
      await _enterPhone(tester, '9841234567');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '984 123 4567',
      );
    });

    testWidgets('nothing is said about an empty or half-typed number', (
      tester,
    ) async {
      await _open(tester, AppRoutes.authPhone);
      expect(find.text('Enter your phone number'), findsNothing);

      await _enterPhone(tester, '98412');
      expect(find.text('That number looks too short'), findsNothing);
    });

    testWidgets('a short number is explained once the field is left', (
      tester,
    ) async {
      await _open(tester, AppRoutes.authPhone);
      await _enterPhone(tester, '98412');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpFrames(tester);

      expect(find.text('That number looks too short'), findsOneWidget);
      expect(find.byType(VerifyScreen), findsNothing);
    });

    testWidgets('a wrong prefix is explained immediately', (tester) async {
      await _open(tester, AppRoutes.authPhone);
      await _enterPhone(tester, '1234567890');

      expect(
        find.text('Nepal mobile numbers start with 96, 97 or 98'),
        findsOneWidget,
      );
      expect(_enabled(tester, 'Send code'), isFalse);
    });

    testWidgets('letters are ignored and extra digits are cut off', (
      tester,
    ) async {
      await _open(tester, AppRoutes.authPhone);

      await _enterPhone(tester, 'abc98x41');
      var text = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller
          .text;
      expect(text, '984 1');

      await _enterPhone(tester, '984123456789012');
      text = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller
          .text;
      expect(text.replaceAll(' ', '').length, 10);
      expect(_enabled(tester, 'Send code'), isTrue);
    });

    testWidgets('changing country re-applies that country\'s rules', (
      tester,
    ) async {
      await _open(tester, AppRoutes.authPhone);

      // Valid in India, wrong prefix for Nepal.
      await _enterPhone(tester, '6123456789');
      expect(_enabled(tester, 'Send code'), isFalse);

      await tester.tap(find.text('+977'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('India'));
      await tester.pumpAndSettle();

      expect(find.text('+91'), findsOneWidget);
      expect(_enabled(tester, 'Send code'), isTrue);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '61234 56789',
        reason: 're-grouped for India',
      );
    });

    testWidgets('sends the code and moves to verification', (tester) async {
      final router = await _open(tester, AppRoutes.authPhone);
      await _enterPhone(tester, '9841234567');

      await tester.tap(_button('Send code'));
      await pumpFrames(tester);

      expect(find.byType(VerifyScreen), findsOneWidget);
      expect(currentPath(router), AppRoutes.authVerify);
      expect(find.textContaining('123456'), findsWidgets);
    });

    testWidgets('shows a loading state while the code is being sent', (
      tester,
    ) async {
      await _open(tester, AppRoutes.authPhone, authRepository: _slowRepository);
      await _enterPhone(tester, '9841234567');

      await tester.tap(_button('Send code'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(_appButton(tester, 'Send code').isLoading, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.pump(const Duration(milliseconds: 600));
      await pumpFrames(tester);
      expect(find.byType(VerifyScreen), findsOneWidget);
    });

    testWidgets('a network error can be retried', (tester) async {
      await _open(tester, AppRoutes.authPhone);
      await _enterPhone(tester, '9841230000');

      await tester.tap(_button('Send code'));
      await pumpFrames(tester);

      expect(find.text('You\'re offline'), findsOneWidget);
      expect(find.byType(VerifyScreen), findsNothing);

      await tester.tap(find.text('Try again'));
      await pumpFrames(tester);
      expect(find.byType(VerifyScreen), findsOneWidget);
    });

    testWidgets('a generic failure is shown and stays on the screen', (
      tester,
    ) async {
      await _open(tester, AppRoutes.authPhone);
      await _enterPhone(tester, '9841231111');

      await tester.tap(_button('Send code'));
      await pumpFrames(tester);

      expect(find.text('Sign-in failed'), findsOneWidget);
      expect(find.byType(PhoneScreen), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await pumpFrames(tester);
      expect(find.text('Sign-in failed'), findsOneWidget);
    });

    testWidgets('the error clears when the number is edited', (tester) async {
      await _open(tester, AppRoutes.authPhone);
      await _enterPhone(tester, '9841231111');
      await tester.tap(_button('Send code'));
      await pumpFrames(tester);
      expect(find.text('Sign-in failed'), findsOneWidget);

      await _enterPhone(tester, '984123111');
      expect(find.text('Sign-in failed'), findsNothing);
    });

    testWidgets('asks for a phone number', (tester) async {
      await _open(tester, AppRoutes.authPhone);
      expect(find.textContaining('number'), findsWidgets);
      expect(find.textContaining('Development mock'), findsNothing);
    });
  });

  group('verification screen', () {
    final path = AppRoutes.verifyWithPhone('+9779841234567');

    testWidgets('shows the development OTP and the code field', (tester) async {
      await _open(tester, path);

      expect(find.textContaining('123456'), findsWidgets);
      expect(find.textContaining('Development mock'), findsNothing);
      expect(find.byType(OtpInput), findsOneWidget);
    });

    testWidgets('the Verify button waits for a complete code', (tester) async {
      await _open(tester, path);
      expect(_enabled(tester, 'Verify'), isFalse);

      await tester.enterText(_otpField(), '12345');
      await tester.pump();
      expect(_enabled(tester, 'Verify'), isFalse);
      for (final digit in ['1', '2', '3', '4', '5']) {
        expect(find.text(digit), findsOneWidget);
      }
    });

    testWidgets('the right code continues into onboarding', (tester) async {
      final router = await _open(tester, path);

      await tester.enterText(_otpField(), '123456');
      await pumpFrames(tester);

      expect(find.byType(SignupGenderScreen), findsOneWidget);
      expect(currentPath(router), AppRoutes.onboardingGender);
      expect(
        containerOf(tester).read(sessionProvider).status,
        AuthStatus.needsGender,
      );
    });

    testWidgets('a login code opens the app and skips setup', (tester) async {
      final router = await _open(
        tester,
        AppRoutes.verifyWithPhone('+9779841234567', login: true),
      );

      expect(find.text('STEP 2 OF 3'), findsNothing);
      expect(find.textContaining('SMS is not sent yet'), findsOneWidget);
      expect(find.textContaining('123456'), findsWidgets);
      await tester.enterText(_otpField(), '123456');
      await pumpFrames(tester);

      expect(currentPath(router), AppRoutes.discover);
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(find.byType(TermsScreen), findsNothing);
      expect(
        containerOf(tester).read(sessionProvider).status,
        AuthStatus.loggedIn,
      );
    });

    testWidgets('the Verify button submits a complete code too', (
      tester,
    ) async {
      await _open(tester, path);

      // 111111 fails every time, so the button is the way to try again.
      await tester.enterText(_otpField(), '111111');
      await pumpFrames(tester);
      expect(find.text('Sign-in failed'), findsOneWidget);

      await tester.tap(_button('Verify'));
      await pumpFrames(tester);
      expect(find.text('Sign-in failed'), findsOneWidget);
    });

    testWidgets('a wrong code is explained and clears when edited', (
      tester,
    ) async {
      await _open(tester, path);

      await tester.enterText(_otpField(), '654321');
      await pumpFrames(tester);
      expect(find.text(_wrongCode), findsOneWidget);
      expect(find.byType(VerifyScreen), findsOneWidget);

      await tester.enterText(_otpField(), '65432');
      await tester.pump();
      expect(find.text(_wrongCode), findsNothing);
    });

    testWidgets('an expired code offers a new one straight away', (
      tester,
    ) async {
      await _open(tester, path);

      await tester.enterText(_otpField(), '000000');
      await pumpFrames(tester);

      expect(find.text(_expiredCode), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Resend code'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsNothing);
    });

    testWidgets('a generic authentication failure can be retried', (
      tester,
    ) async {
      await _open(tester, path);

      await tester.enterText(_otpField(), '111111');
      await pumpFrames(tester);

      expect(find.text('Sign-in failed'), findsOneWidget);
      expect(
        find.text('We couldn\'t sign you in. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a network error can be retried and then succeeds', (
      tester,
    ) async {
      await _open(tester, path);

      await tester.enterText(_otpField(), '222222');
      await pumpFrames(tester);
      expect(find.text('You\'re offline'), findsOneWidget);
      expect(find.byType(SignupGenderScreen), findsNothing);

      await tester.tap(find.text('Try again'));
      await pumpFrames(tester);
      expect(find.byType(SignupGenderScreen), findsOneWidget);
    });

    testWidgets('shows loading and locks the code while verifying', (
      tester,
    ) async {
      await _open(tester, path, authRepository: _slowRepository);

      await tester.enterText(_otpField(), '123456');
      await tester.pump(const Duration(milliseconds: 100));

      expect(_appButton(tester, 'Verify').isLoading, isTrue);
      expect(tester.widget<TextField>(_otpField()).enabled, isFalse);
      expect(find.byType(SignupGenderScreen), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      await pumpFrames(tester);
      expect(find.byType(SignupGenderScreen), findsOneWidget);
    });

    testWidgets('resend: countdown, then a button, then a fresh countdown', (
      tester,
    ) async {
      await _open(tester, path);
      expect(find.textContaining('Resend code in 0:'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Resend code'), findsNothing);

      await tester.pump(AppConstants.resendCooldown);
      expect(find.widgetWithText(TextButton, 'Resend code'), findsOneWidget);

      await tester.enterText(_otpField(), '12');
      await tester.tap(find.text('Resend code'));
      await pumpFrames(tester);

      expect(find.text('A new code was requested.'), findsOneWidget);
      expect(find.textContaining('Resend code in 0:'), findsOneWidget);
      expect(
        tester.widget<TextField>(_otpField()).controller?.text,
        isEmpty,
        reason: 'the old digits are cleared',
      );
    });

    testWidgets('a failed resend is reported and can be retried', (
      tester,
    ) async {
      // Sending to a number ending 0000 fails once with a network error.
      await _open(tester, AppRoutes.verifyWithPhone('+9779841230000'));
      await tester.pump(AppConstants.resendCooldown);

      await tester.tap(find.text('Resend code'));
      await pumpFrames(tester);
      expect(find.text('You\'re offline'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await pumpFrames(tester);
      expect(find.text('You\'re offline'), findsNothing);
    });

    testWidgets('"Change number" goes back to the phone screen', (
      tester,
    ) async {
      await _open(tester, AppRoutes.authPhone);
      await _enterPhone(tester, '9841234567');
      await tester.tap(_button('Send code'));
      await pumpFrames(tester);
      expect(find.byType(VerifyScreen), findsOneWidget);

      await tester.tap(find.text('Change number'));
      await pumpFrames(tester);

      expect(find.byType(PhoneScreen), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '984 123 4567',
        reason: 'the number is kept for editing',
      );
    });

    testWidgets('"Change number" works when opened directly', (tester) async {
      await _open(tester, path);
      await tester.tap(find.text('Change number'));
      await pumpFrames(tester);
      expect(find.byType(PhoneScreen), findsOneWidget);
    });
  });

  group('terms, privacy and age acknowledgements', () {
    testWidgets('shows step 3 of 5 and starts with nothing ticked', (
      tester,
    ) async {
      await _open(
        tester,
        AppRoutes.onboardingTerms,
        session: AuthStatus.needsTerms,
      );

      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.text('Step 3 of 5 · Terms'), findsOneWidget);
      for (final box in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
        expect(box.value, isFalse);
      }
      expect(_enabled(tester, 'Agree and continue'), isFalse);
    });

    testWidgets('all three acknowledgements are required', (tester) async {
      await _open(
        tester,
        AppRoutes.onboardingTerms,
        session: AuthStatus.needsTerms,
      );

      await tester.tap(find.text('I agree to the Terms of Service'));
      await tester.pump();
      await tester.tap(find.text('I have read the Privacy Policy'));
      await tester.pump();
      expect(_enabled(tester, 'Agree and continue'), isFalse);

      await tester.tap(find.text('I am 18 years old or older'));
      await tester.pump();
      expect(_enabled(tester, 'Agree and continue'), isTrue);

      await tester.tap(find.text('I am 18 years old or older'));
      await tester.pump();
      expect(_enabled(tester, 'Agree and continue'), isFalse);
    });

    testWidgets('the documents can be read without losing ticks', (
      tester,
    ) async {
      await _open(
        tester,
        AppRoutes.onboardingTerms,
        session: AuthStatus.needsTerms,
      );
      await tester.tap(find.text('I agree to the Terms of Service'));
      await tester.pump();

      await tester.tap(find.text('Read').first);
      await pumpFrames(tester);
      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.text('Terms of Service'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await pumpFrames(tester);
      expect(find.byType(TermsScreen), findsOneWidget);
      expect(
        tester.widgetList<Checkbox>(find.byType(Checkbox)).first.value,
        isTrue,
      );

      await tester.tap(find.text('Read').last);
      await pumpFrames(tester);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('What we collect'), findsOneWidget);
    });

    testWidgets('agreeing continues to the birth date step', (tester) async {
      final router = await _open(
        tester,
        AppRoutes.onboardingTerms,
        session: AuthStatus.needsTerms,
      );
      for (final label in [
        'I agree to the Terms of Service',
        'I have read the Privacy Policy',
        'I am 18 years old or older',
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
      }

      await tester.tap(_button('Agree and continue'));
      await pumpFrames(tester);

      expect(find.byType(BirthDateScreen), findsOneWidget);
      expect(currentPath(router), AppRoutes.onboardingBirthDate);
    });

    testWidgets('a failure can be retried', (tester) async {
      late _FlakyAuthRepository flaky;
      await _open(
        tester,
        AppRoutes.onboardingTerms,
        session: AuthStatus.needsTerms,
        authRepository: (now, saved) => flaky = _FlakyAuthRepository(now: now),
      );
      for (final label in [
        'I agree to the Terms of Service',
        'I have read the Privacy Policy',
        'I am 18 years old or older',
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
      }

      await tester.tap(_button('Agree and continue'));
      await pumpFrames(tester);
      expect(find.text('You\'re offline'), findsOneWidget);
      expect(find.byType(TermsScreen), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await pumpFrames(tester);
      expect(find.byType(BirthDateScreen), findsOneWidget);
      expect(flaky.failNextTerms, isFalse);
    });

    testWidgets('signing out is always possible mid-setup', (tester) async {
      await _open(
        tester,
        AppRoutes.onboardingTerms,
        session: AuthStatus.needsTerms,
      );

      await tester.tap(find.text('Sign out'));
      await pumpFrames(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('You\'ve been signed out.'), findsOneWidget);
    });
  });

  group('date of birth and age eligibility', () {
    Future<void> openBirthDate(WidgetTester tester) => _open(
      tester,
      AppRoutes.onboardingBirthDate,
      session: AuthStatus.needsBirthDate,
    );

    testWidgets('shows step 4 of 5, the 18+ rule and a disabled Continue', (
      tester,
    ) async {
      await openBirthDate(tester);

      expect(find.text('Step 4 of 5 · Date of birth'), findsOneWidget);
      expect(find.text('You must be 18 or older.'), findsOneWidget);
      expect(_enabled(tester, 'Continue'), isFalse);
    });

    testWidgets('an adult date shows a positive message and enables Continue', (
      tester,
    ) async {
      await openBirthDate(tester);
      await _enterDate(tester, '14', '10', '1998');

      expect(
        find.textContaining('You meet the 18+ requirement'),
        findsOneWidget,
      );
      expect(_enabled(tester, 'Continue'), isTrue);
    });

    testWidgets('turning 18 today is eligible', (tester) async {
      await openBirthDate(tester);
      await _enterDate(tester, '14', '10', '2008');

      expect(
        find.textContaining('You meet the 18+ requirement'),
        findsOneWidget,
      );
      expect(find.textContaining('You need to be 18'), findsNothing);
    });

    testWidgets('one day short of 18 is not eligible', (tester) async {
      await openBirthDate(tester);
      await _enterDate(tester, '15', '10', '2008');

      expect(find.text('You need to be 18 or older'), findsOneWidget);
      expect(find.textContaining('You meet the 18+'), findsNothing);
      // The date is real, so it can still be submitted to see the result.
      expect(_enabled(tester, 'Continue'), isTrue);
    });

    testWidgets('impossible and future dates cannot be submitted', (
      tester,
    ) async {
      await openBirthDate(tester);

      await _enterDate(tester, '31', '02', '1995');
      expect(
        find.text('That date doesn\'t exist. Check the day.'),
        findsOneWidget,
      );
      expect(_enabled(tester, 'Continue'), isFalse);

      await _enterDate(tester, '01', '01', '2030');
      expect(
        find.text('Your birth date can\'t be in the future.'),
        findsOneWidget,
      );
      expect(_enabled(tester, 'Continue'), isFalse);
    });

    testWidgets('an eligible date continues to gender', (tester) async {
      final router = await _open(
        tester,
        AppRoutes.onboardingBirthDate,
        session: AuthStatus.needsBirthDate,
      );
      await _enterDate(tester, '07', '03', '1995');

      await tester.tap(_button('Continue'));
      await pumpFrames(tester);

      expect(find.byType(SignupGenderScreen), findsOneWidget);
      expect(currentPath(router), AppRoutes.onboardingGender);
      expect(
        containerOf(tester).read(sessionProvider).status,
        AuthStatus.needsGender,
      );
    });

    testWidgets('an under-age date shows the blocked state', (tester) async {
      await openBirthDate(tester);
      await _enterDate(tester, '15', '10', '2008');

      await tester.tap(_button('Continue'));
      await pumpFrames(tester);

      expect(find.byType(IneligibleScreen), findsOneWidget);
      expect(find.text('You can\'t use Social Dating yet'), findsOneWidget);
      expect(
        containerOf(tester).read(sessionProvider).status,
        AuthStatus.ineligible,
      );
    });

    testWidgets('does not promise to store the birth date', (tester) async {
      await openBirthDate(tester);
      expect(find.textContaining('not saved on this device'), findsOneWidget);
    });
  });

  group('under-age users are kept out of the dating UI', () {
    testWidgets('every dating route returns to the blocked screen', (
      tester,
    ) async {
      final router = await _open(
        tester,
        AppRoutes.onboardingIneligible,
        session: AuthStatus.ineligible,
      );

      for (final path in [
        AppRoutes.discover,
        AppRoutes.matches,
        AppRoutes.chat,
        AppRoutes.profile,
        AppRoutes.settings,
        AppRoutes.profileCompletion,
        AppRoutes.welcome,
      ]) {
        router.go(path);
        await pumpFrames(tester);
        expect(find.byType(IneligibleScreen), findsOneWidget, reason: path);
        expect(find.byType(DiscoveryScreen), findsNothing, reason: path);
        expect(currentPath(router), AppRoutes.onboardingIneligible);
      }
    });

    testWidgets('has no way into the app, only sign out or delete', (
      tester,
    ) async {
      await _open(
        tester,
        AppRoutes.onboardingIneligible,
        session: AuthStatus.ineligible,
      );
      expect(_button('Sign out'), findsOneWidget);
      expect(_button('Delete my data'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('signing out returns to the welcome screen', (tester) async {
      await _open(
        tester,
        AppRoutes.onboardingIneligible,
        session: AuthStatus.ineligible,
      );
      await tester.tap(_button('Sign out'));
      await pumpFrames(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('deleting data asks first, then signs out with a notice', (
      tester,
    ) async {
      await _open(
        tester,
        AppRoutes.onboardingIneligible,
        session: AuthStatus.ineligible,
      );

      await tester.tap(_button('Delete my data'));
      await pumpFrames(tester);
      expect(find.text('Delete your data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(find.byType(IneligibleScreen), findsOneWidget);

      await tester.tap(_button('Delete my data'));
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(of: find.byType(Dialog), matching: find.text('Delete')),
      );
      await pumpFrames(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        find.text('Your account details were deleted from this device.'),
        findsOneWidget,
      );
    });
  });

  group('completion state', () {
    testWidgets('shows a complete progress bar and a greeting', (tester) async {
      await _open(
        tester,
        AppRoutes.onboardingComplete,
        session: AuthStatus.onboardingComplete,
      );

      expect(find.byType(OnboardingCompleteScreen), findsOneWidget);
      expect(find.text('Setup complete'), findsOneWidget);
      expect(find.text('You\'re all set, Mock User'), findsOneWidget);
    });

    testWidgets('"Start exploring" enters the app', (tester) async {
      final router = await _open(
        tester,
        AppRoutes.onboardingComplete,
        session: AuthStatus.onboardingComplete,
      );

      await tester.tap(_button('Start exploring'));
      await pumpFrames(tester);

      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(currentPath(router), AppRoutes.discover);
      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isTrue);
    });
  });

  group('session expired', () {
    testWidgets('shows the expired state and the masked number', (
      tester,
    ) async {
      await _open(
        tester,
        AppRoutes.discover,
        session: AuthStatus.sessionExpired,
      );

      expect(find.byType(SessionExpiredScreen), findsOneWidget);
      expect(find.text('Your session expired'), findsOneWidget);
      expect(find.textContaining('4567'), findsOneWidget);
      expect(find.textContaining('9841234567'), findsNothing);
    });

    testWidgets('a live session can expire while the app is open', (
      tester,
    ) async {
      await _open(tester, AppRoutes.discover, session: AuthStatus.loggedIn);
      expect(find.byType(DiscoveryScreen), findsOneWidget);

      containerOf(tester).read(sessionProvider.notifier).expireSession();
      await pumpFrames(tester);

      expect(find.byType(SessionExpiredScreen), findsOneWidget);
      expect(find.byType(DiscoveryScreen), findsNothing);
    });

    testWidgets('"Log in again" opens the login flow and signs back in', (
      tester,
    ) async {
      await _open(
        tester,
        AppRoutes.discover,
        session: null,
        prefs: savedSession(
          status: AuthStatus.loggedIn,
          displayName: 'Sam',
          account: const AccountState(
            id: 'acc-1',
            termsAccepted: true,
            isAgeEligible: true,
            displayName: 'Sam',
          ),
          savedAt: testNow.subtract(const Duration(days: 45)),
        ),
      );
      expect(find.byType(SessionExpiredScreen), findsOneWidget);

      await tester.tap(_button('Log in again'));
      await pumpFrames(tester);
      expect(find.text('Welcome back'), findsOneWidget);

      await _enterPhone(tester, '9841234567');
      await tester.tap(_button('Send code'));
      await pumpFrames(tester);
      await tester.enterText(_otpField(), '123456');
      await pumpFrames(tester);

      // The same account, so no onboarding is repeated.
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(containerOf(tester).read(sessionProvider).displayName, 'Sam');
    });

    testWidgets('"Back to start" leaves the expired session', (tester) async {
      await _open(
        tester,
        AppRoutes.discover,
        session: AuthStatus.sessionExpired,
      );
      await tester.tap(_button('Back to start'));
      await pumpFrames(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('app restart with a saved mock session', () {
    const account = AccountState(
      id: 'acc-1',
      termsAccepted: true,
      isAgeEligible: true,
      displayName: 'Sam',
    );

    testWidgets('no saved session starts at the welcome screen', (
      tester,
    ) async {
      await _open(tester, AppRoutes.splash, session: null);
      await tester.pump(AppConstants.splashDuration);
      await pumpFrames(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('a finished session goes straight to the app', (tester) async {
      await _open(
        tester,
        AppRoutes.splash,
        session: null,
        prefs: savedSession(
          status: AuthStatus.loggedIn,
          displayName: 'Sam',
          account: account,
        ),
      );
      await tester.pump(AppConstants.splashDuration);
      await pumpFrames(tester);

      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(containerOf(tester).read(sessionProvider).displayName, 'Sam');
    });

    testWidgets('each onboarding step is resumed', (tester) async {
      final expectations = <AuthStatus, Type>{
        AuthStatus.needsTerms: TermsScreen,
        AuthStatus.needsBirthDate: BirthDateScreen,
        AuthStatus.needsGender: SignupGenderScreen,
        AuthStatus.incompleteProfile: SignupNameScreen,
        AuthStatus.onboardingComplete: OnboardingCompleteScreen,
      };
      for (final MapEntry(key: status, value: screen) in expectations.entries) {
        await _open(
          tester,
          AppRoutes.welcome,
          session: null,
          prefs: savedSession(status: status, account: account),
        );
        expect(find.byType(screen), findsOneWidget, reason: '$status');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('an under-age block persists across restarts', (tester) async {
      await _open(
        tester,
        AppRoutes.discover,
        session: null,
        prefs: savedSession(
          status: AuthStatus.ineligible,
          account: const AccountState(
            id: 'acc-2',
            termsAccepted: true,
            isAgeEligible: false,
          ),
          savedAt: testNow.subtract(const Duration(days: 400)),
        ),
      );
      expect(find.byType(IneligibleScreen), findsOneWidget);
      expect(find.byType(DiscoveryScreen), findsNothing);
    });

    testWidgets('an old session is shown as expired', (tester) async {
      await _open(
        tester,
        AppRoutes.welcome,
        session: null,
        prefs: savedSession(
          status: AuthStatus.loggedIn,
          account: account,
          savedAt: testNow.subtract(
            AppConstants.sessionMaxAge + const Duration(days: 1),
          ),
        ),
      );
      expect(find.byType(SessionExpiredScreen), findsOneWidget);
    });

    testWidgets('a corrupt saved value is ignored', (tester) async {
      await _open(
        tester,
        AppRoutes.discover,
        session: null,
        prefs: {StorageKeys.sessionSnapshot: '{broken'},
      );
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('completing the flow, then restarting, keeps you in', (
      tester,
    ) async {
      await _open(
        tester,
        AppRoutes.onboardingComplete,
        session: AuthStatus.onboardingComplete,
      );
      await tester.tap(_button('Start exploring'));
      await pumpFrames(tester);
      expect(find.byType(DiscoveryScreen), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(StorageKeys.sessionSnapshot);
      expect(saved, isNotNull);
      expect(saved, contains('"status":"loggedIn"'));
      expect(saved, isNot(contains('9841234567')));
      expect(saved!.toLowerCase(), isNot(contains('token')));

      await tester.pumpWidget(const SizedBox());
      await _open(
        tester,
        AppRoutes.welcome,
        session: null,
        prefs: {StorageKeys.sessionSnapshot: saved},
      );
      expect(find.byType(DiscoveryScreen), findsOneWidget);
    });

    testWidgets('signing out clears the saved session', (tester) async {
      await _open(tester, AppRoutes.discover, session: AuthStatus.loggedIn);
      containerOf(tester).read(sessionProvider.notifier).signOut();
      await pumpFrames(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.sessionSnapshot), isNull);
    });
  });

  group('complete sign-up journey with sample data', () {
    testWidgets('phone -> code -> gender -> name -> app', (tester) async {
      final router = await _open(tester, AppRoutes.authPhone);
      expect(currentPath(router), AppRoutes.authPhone);

      await _enterPhone(tester, '9841234567');
      await tester.tap(_button('Send code'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.authVerify);

      await tester.enterText(_otpField(), '123456');
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.onboardingGender);
      expect(find.byType(SignupGenderScreen), findsOneWidget);

      await tester.tap(find.text('Female'));
      await tester.pump();
      await tester.tap(_button('Continue'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.profileCompletion);
      expect(find.byType(SignupNameScreen), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Sam',
      );
      await tester.tap(_button('Continue'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.discover);
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(
        containerOf(tester).read(sessionProvider).status,
        AuthStatus.loggedIn,
      );
    });

    testWidgets('the under-age journey ends on the blocked screen', (
      tester,
    ) async {
      final router = await _open(
        tester,
        AppRoutes.onboardingBirthDate,
        session: AuthStatus.needsBirthDate,
      );
      await _enterDate(tester, '01', '01', '2015');
      await tester.tap(_button('Continue'));
      await pumpFrames(tester);

      expect(currentPath(router), AppRoutes.onboardingIneligible);
      router.go(AppRoutes.discover);
      await pumpFrames(tester);
      expect(find.byType(DiscoveryScreen), findsNothing);
      expect(find.byType(IneligibleScreen), findsOneWidget);
    });
  });
}
