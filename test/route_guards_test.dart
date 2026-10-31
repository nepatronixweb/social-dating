import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_dating/core/constants/app_constants.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/routing/route_guards.dart';
import 'package:social_dating/core/utils/connectivity_provider.dart';
import 'package:social_dating/core/widgets/app_bottom_nav.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/features/auth/presentation/session_expired_screen.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/discovery/presentation/discovery_screen.dart';
import 'package:social_dating/features/onboarding/presentation/birth_date_screen.dart';
import 'package:social_dating/features/onboarding/presentation/ineligible_screen.dart';
import 'package:social_dating/features/onboarding/presentation/onboarding_complete_screen.dart';
import 'package:social_dating/features/onboarding/presentation/terms_screen.dart';
import 'package:social_dating/features/onboarding/presentation/welcome_screen.dart';
import 'package:social_dating/features/onboarding/presentation/signup_gender_screen.dart';
import 'package:social_dating/features/onboarding/presentation/signup_name_screen.dart';
import 'package:social_dating/features/settings/presentation/account_screen.dart';
import 'package:social_dating/features/wallet/presentation/wallet_screen.dart';

import 'helpers/pump_app.dart';

const _protected = [
  '/discover',
  '/likes',
  '/matches',
  '/chat',
  '/chat/abc',
  '/profile',
  '/subscription',
  '/wallet',
  '/referrals',
  '/notifications',
  '/settings',
  '/safety',
  '/account',
];

const _onboardingScreens = [
  '/onboarding/terms',
  '/onboarding/birthdate',
  '/onboarding/ineligible',
  '/onboarding/gender',
  '/profile-completion',
  '/onboarding/complete',
];

const _authScreens = ['/welcome', '/auth/phone', '/auth/verify?phone=1'];

void main() {
  group('sessionRedirect (pure guard)', () {
    test('logged out: everything behind sign-in -> welcome', () {
      for (final path in [
        ..._protected,
        ..._onboardingScreens,
        '/session-expired',
      ]) {
        expect(
          sessionRedirect(AuthStatus.loggedOut, path),
          AppRoutes.welcome,
          reason: path,
        );
      }
    });

    test('logged out: public routes are allowed', () {
      for (final path in [
        '/splash',
        ..._authScreens,
        '/auth/phone?mode=login',
        '/auth/verify?phone=%2B9779841234567&mode=login',
      ]) {
        expect(
          sessionRedirect(AuthStatus.loggedOut, path),
          isNull,
          reason: path,
        );
      }
    });

    test('session expired: the app and onboarding -> the expired screen', () {
      for (final path in [..._protected, ..._onboardingScreens, '/welcome']) {
        expect(
          sessionRedirect(AuthStatus.sessionExpired, path),
          AppRoutes.sessionExpired,
          reason: path,
        );
      }
      // Logging in again uses the auth screens.
      for (final path in [
        '/session-expired',
        '/auth/phone?mode=login',
        '/auth/verify?phone=1&mode=login',
      ]) {
        expect(
          sessionRedirect(AuthStatus.sessionExpired, path),
          isNull,
          reason: path,
        );
      }
    });

    test('each unfinished status funnels to exactly one screen', () {
      const homes = {
        AuthStatus.needsTerms: '/onboarding/terms',
        AuthStatus.needsBirthDate: '/onboarding/birthdate',
        AuthStatus.needsGender: '/onboarding/gender',
        AuthStatus.ineligible: '/onboarding/ineligible',
        AuthStatus.incompleteProfile: '/profile-completion',
        AuthStatus.onboardingComplete: '/onboarding/complete',
      };
      for (final MapEntry(key: status, value: home) in homes.entries) {
        expect(homeFor(status), home);
        for (final path in [
          // Discovery stays open while the profile is incomplete (first swipes).
          ..._protected.where(
            (p) => status != AuthStatus.incompleteProfile || p != '/discover',
          ),
          ..._authScreens,
          '/session-expired',
          ..._onboardingScreens.where((p) => p != home),
        ]) {
          expect(sessionRedirect(status, path), home, reason: '$status $path');
        }
        expect(sessionRedirect(status, home), isNull, reason: '$status');
      }
    });

    test('incomplete profile: only discovery is open besides completion', () {
      for (final path in [
        '/discover',
        '/discover/profile/mock-1',
        '/profile-completion',
      ]) {
        expect(
          sessionRedirect(AuthStatus.incompleteProfile, path),
          isNull,
          reason: path,
        );
      }
      for (final path in [
        ..._protected.where((p) => p != '/discover'),
        ..._authScreens,
        '/onboarding/complete',
      ]) {
        expect(
          sessionRedirect(AuthStatus.incompleteProfile, path),
          AppRoutes.profileCompletion,
          reason: path,
        );
      }
    });

    test('under-age sessions can never reach any dating screen', () {
      for (final path in _protected) {
        expect(
          sessionRedirect(AuthStatus.ineligible, path),
          AppRoutes.onboardingIneligible,
          reason: path,
        );
      }
    });

    test('logged in: auth and onboarding screens -> discover', () {
      for (final path in [
        ..._authScreens,
        ..._onboardingScreens,
        '/session-expired',
      ]) {
        expect(
          sessionRedirect(AuthStatus.loggedIn, path),
          AppRoutes.discover,
          reason: path,
        );
      }
      for (final path in _protected) {
        expect(
          sessionRedirect(AuthStatus.loggedIn, path),
          isNull,
          reason: path,
        );
      }
    });

    test('legal documents are readable in every state', () {
      for (final status in AuthStatus.values) {
        expect(sessionRedirect(status, '/legal/terms'), isNull);
        expect(sessionRedirect(status, '/legal/privacy'), isNull);
      }
    });

    test('splash, dev tools and unknown paths are never redirected', () {
      for (final status in AuthStatus.values) {
        expect(sessionRedirect(status, '/splash'), isNull);
        expect(sessionRedirect(status, '/dev/design-system'), isNull);
        expect(sessionRedirect(status, '/does-not-exist'), isNull);
      }
    });

    test('"/profile-completion" is not mistaken for the "/profile" tab', () {
      expect(
        sessionRedirect(AuthStatus.loggedOut, '/profile-completion'),
        AppRoutes.welcome,
      );
      expect(
        sessionRedirect(AuthStatus.incompleteProfile, '/profile-completion'),
        isNull,
      );
      expect(
        sessionRedirect(AuthStatus.loggedIn, '/profile-completion'),
        AppRoutes.discover,
      );
    });

    test('every status has a home route', () {
      for (final status in AuthStatus.values) {
        expect(homeFor(status), isNotEmpty);
      }
    });
  });

  group('session notifier + mock auth repository', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<void> signIn(SessionNotifier notifier) =>
        notifier.signInWithPhone(phone: '+9779841234567', code: '123456');

    test('starts logged out', () {
      final container = makeSessionContainer(prefs);
      expect(container.read(sessionProvider).status, AuthStatus.loggedOut);
    });

    test(
      'a wrong code is rejected and leaves the session logged out',
      () async {
        final container = makeSessionContainer(prefs);
        final notifier = container.read(sessionProvider.notifier);

        await expectLater(
          notifier.signInWithPhone(phone: '+9779841234567', code: '654321'),
          throwsA(isA<InvalidCodeFailure>()),
        );
        expect(container.read(sessionProvider).status, AuthStatus.loggedOut);
      },
    );

    test('expired, failing and transient-network codes', () async {
      final container = makeSessionContainer(prefs);
      final notifier = container.read(sessionProvider.notifier);
      const phone = '+9779841234567';

      await expectLater(
        notifier.signInWithPhone(phone: phone, code: '000000'),
        throwsA(isA<CodeExpiredFailure>()),
      );
      await expectLater(
        notifier.signInWithPhone(phone: phone, code: '111111'),
        throwsA(isA<AuthenticationFailure>()),
      );
      // 222222 fails once with a network error, then works.
      await expectLater(
        notifier.signInWithPhone(phone: phone, code: '222222'),
        throwsA(isA<NetworkFailure>()),
      );
      await notifier.signInWithPhone(phone: phone, code: '222222');
      expect(container.read(sessionProvider).status, AuthStatus.needsGender);
    });

    test('login with a valid code opens a finished session', () async {
      final container = makeSessionContainer(prefs);
      final notifier = container.read(sessionProvider.notifier);

      await notifier.signInWithPhone(
        phone: '+9779841234567',
        code: '123456',
        login: true,
      );
      expect(container.read(sessionProvider).status, AuthStatus.loggedIn);
      expect(container.read(sessionProvider).displayName, 'You');
    });

    test(
      'a number that already has an account skips setup on create-account',
      () async {
        final container = makeSessionContainer(prefs);
        final notifier = container.read(sessionProvider.notifier);

        await notifier.signInWithPhone(
          phone: '+9779841234567',
          code: '123456',
        );
        expect(container.read(sessionProvider).status, AuthStatus.needsGender);

        notifier.signOut();
        expect(container.read(sessionProvider).status, AuthStatus.loggedOut);
        expect(await notifier.sendCode('+9779841234567'), isTrue);

        await notifier.signInWithPhone(
          phone: '+9779841234567',
          code: '123456',
        );
        expect(container.read(sessionProvider).status, AuthStatus.loggedIn);
        expect(container.read(sessionProvider).displayName, 'You');
      },
    );

    test('sending a code can fail with a network or generic error', () async {
      final notifier = makeSessionContainer(
        prefs,
      ).read(sessionProvider.notifier);

      await expectLater(
        notifier.sendCode('+9779841230000'),
        throwsA(isA<NetworkFailure>()),
      );
      await notifier.sendCode('+9779841230000'); // works on retry
      await expectLater(
        notifier.sendCode('+9779841231111'),
        throwsA(isA<AuthenticationFailure>()),
      );
      await notifier.sendCode('+9779841234567');
    });

    test('the whole first-time journey, step by step', () async {
      final container = makeSessionContainer(prefs);
      final notifier = container.read(sessionProvider.notifier);
      AuthStatus status() => container.read(sessionProvider).status;

      await signIn(notifier);
      expect(status(), AuthStatus.needsGender);
      expect(container.read(sessionProvider).phone, '+9779841234567');
      expect(
        container.read(sessionProvider).phoneLabel,
        isNot(contains('984')),
      );

      await notifier.setGender('female');
      expect(status(), AuthStatus.incompleteProfile);

      await notifier.completeProfile(displayName: 'Sam', gender: 'female');
      expect(status(), AuthStatus.loggedIn);
      expect(container.read(sessionProvider).displayName, 'Sam');

      notifier.signOut();
      expect(status(), AuthStatus.loggedOut);

      // The mock server remembers the finished account.
      await signIn(notifier);
      expect(status(), AuthStatus.loggedIn);
    });

    test('finishOnboarding does nothing before onboarding is complete', () {
      final container = makeSessionContainer(prefs);
      container.read(sessionProvider.notifier).finishOnboarding();
      expect(container.read(sessionProvider).status, AuthStatus.loggedOut);
    });

    test('age 18 today is eligible, one day short is not', () async {
      Future<AuthStatus> statusFor(DateTime birth) async {
        SharedPreferences.setMockInitialValues({});
        final p = await SharedPreferences.getInstance();
        final container = makeSessionContainer(p);
        final notifier = container.read(sessionProvider.notifier);
        await signIn(notifier);
        await notifier.acceptTerms();
        await notifier.submitBirthDate(birth);
        return container.read(sessionProvider).status;
      }

      // testNow is 2026-10-14.
      expect(await statusFor(DateTime(2008, 10, 14)), AuthStatus.needsGender);
      expect(await statusFor(DateTime(2008, 10, 15)), AuthStatus.ineligible);
      expect(await statusFor(DateTime(2020, 1, 1)), AuthStatus.ineligible);
    });

    test('deleting the account resets the mock user', () async {
      final container = makeSessionContainer(prefs);
      final notifier = container.read(sessionProvider.notifier);
      await signIn(notifier);
      await notifier.setGender('female');
      await notifier.completeProfile(displayName: 'Sam', gender: 'female');

      await notifier.deleteAccount();
      expect(container.read(sessionProvider).status, AuthStatus.loggedOut);
      expect(
        container.read(sessionNoticeProvider),
        SessionNotice.accountDeleted,
      );

      await signIn(notifier);
      expect(container.read(sessionProvider).status, AuthStatus.needsGender);
    });

    test('signing out leaves a notice for the welcome screen', () async {
      final container = makeSessionContainer(prefs);
      final notifier = container.read(sessionProvider.notifier);
      await signIn(notifier);
      notifier.signOut();
      expect(container.read(sessionNoticeProvider), SessionNotice.signedOut);
    });

    test('the mock flow labels itself as a mock', () {
      final hint = makeSessionContainer(
        prefs,
      ).read(sessionProvider.notifier).signInHint;
      expect(hint, contains('Development mock'));
      expect(hint, contains('no SMS'));
      expect(hint, contains('123456'));
    });

    group('restart behaviour', () {
      Future<ProviderContainer> finishedAccount() async {
        final container = makeSessionContainer(prefs);
        final notifier = container.read(sessionProvider.notifier);
        await signIn(notifier);
        await notifier.setGender('male');
        await notifier.completeProfile(displayName: 'Sam', gender: 'male');
        await pumpEventQueue();
        return container;
      }

      test('the saved snapshot holds no token, phone or birth date', () async {
        await finishedAccount();
        final raw = prefs.getString(StorageKeys.sessionSnapshot)!;

        expect(raw, contains('"status":"loggedIn"'));
        expect(raw.toLowerCase(), isNot(contains('token')));
        expect(raw, isNot(contains('9841234567')));
        expect(raw, isNot(contains('1991')));
        expect(raw, isNot(contains('03-07')));
      });

      test('a finished session is restored without signing in', () async {
        await finishedAccount();

        final restarted = makeSessionContainer(prefs);
        final session = restarted.read(sessionProvider);
        expect(session.status, AuthStatus.loggedIn);
        expect(session.displayName, 'Sam');
        expect(session.phoneLabel, contains('4567'));
        expect(session.phone, isNull, reason: 'the full number is not kept');
      });

      test('onboarding resumes on the step it stopped at', () async {
        final container = makeSessionContainer(prefs);
        final notifier = container.read(sessionProvider.notifier);
        await signIn(notifier);
        await notifier.acceptTerms();
        await pumpEventQueue();

        final restarted = makeSessionContainer(prefs);
        expect(
          restarted.read(sessionProvider).status,
          AuthStatus.needsBirthDate,
        );
        await restarted
            .read(sessionProvider.notifier)
            .submitBirthDate(DateTime(1995, 1, 1));
        expect(
          restarted.read(sessionProvider).status,
          AuthStatus.needsGender,
        );
      });

      test('an under-age result survives a restart', () async {
        final container = makeSessionContainer(prefs);
        final notifier = container.read(sessionProvider.notifier);
        await signIn(notifier);
        await notifier.acceptTerms();
        await notifier.submitBirthDate(DateTime(2015, 6, 1));
        await pumpEventQueue();

        expect(
          makeSessionContainer(prefs).read(sessionProvider).status,
          AuthStatus.ineligible,
        );
      });

      test('a session older than the maximum age is expired', () async {
        await finishedAccount();

        final later = testNow.add(
          AppConstants.sessionMaxAge + const Duration(days: 1),
        );
        final restarted = makeSessionContainer(prefs, clock: () => later);
        expect(
          restarted.read(sessionProvider).status,
          AuthStatus.sessionExpired,
        );

        // Just inside the limit it is still valid.
        final almost = testNow.add(AppConstants.sessionMaxAge);
        expect(
          makeSessionContainer(
            prefs,
            clock: () => almost,
          ).read(sessionProvider).status,
          AuthStatus.loggedIn,
        );
      });

      test('an under-age block never expires into a normal sign-in', () async {
        final container = makeSessionContainer(prefs);
        final notifier = container.read(sessionProvider.notifier);
        await signIn(notifier);
        await notifier.acceptTerms();
        await notifier.submitBirthDate(DateTime(2015, 6, 1));
        await pumpEventQueue();

        final later = testNow.add(const Duration(days: 365));
        expect(
          makeSessionContainer(
            prefs,
            clock: () => later,
          ).read(sessionProvider).status,
          AuthStatus.ineligible,
        );
      });

      test('signing in again after expiry resumes the same account', () async {
        await finishedAccount();
        final later = testNow.add(const Duration(days: 60));
        final restarted = makeSessionContainer(prefs, clock: () => later);
        final notifier = restarted.read(sessionProvider.notifier);
        expect(
          restarted.read(sessionProvider).status,
          AuthStatus.sessionExpired,
        );

        await signIn(notifier);
        expect(restarted.read(sessionProvider).status, AuthStatus.loggedIn);
        expect(restarted.read(sessionProvider).displayName, 'Sam');
      });

      test('signing out forgets the saved session', () async {
        final container = await finishedAccount();
        container.read(sessionProvider.notifier).signOut();
        await pumpEventQueue();

        expect(prefs.getString(StorageKeys.sessionSnapshot), isNull);
        expect(
          makeSessionContainer(prefs).read(sessionProvider).status,
          AuthStatus.loggedOut,
        );
      });

      test('a corrupt snapshot is ignored', () async {
        SharedPreferences.setMockInitialValues({
          StorageKeys.sessionSnapshot: '{not json',
        });
        final p = await SharedPreferences.getInstance();
        expect(
          makeSessionContainer(p).read(sessionProvider).status,
          AuthStatus.loggedOut,
        );
      });
    });
  });

  group('session-dependent navigation', () {
    testWidgets('logged out cannot open a protected route', (tester) async {
      final router = await pumpApp(tester, location: AppRoutes.wallet);
      await pumpFrames(tester);

      expect(find.byType(WalletScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(currentPath(router), AppRoutes.welcome);
    });

    testWidgets('logged out cannot open any onboarding screen', (tester) async {
      for (final location in _onboardingScreens) {
        await pumpApp(tester, location: location);
        await pumpFrames(tester);
        expect(find.byType(WelcomeScreen), findsOneWidget, reason: location);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('each status lands on its own screen', (tester) async {
      final expectations = <AuthStatus, Type>{
        AuthStatus.needsTerms: TermsScreen,
        AuthStatus.needsBirthDate: BirthDateScreen,
        AuthStatus.ineligible: IneligibleScreen,
        AuthStatus.needsGender: SignupGenderScreen,
        AuthStatus.incompleteProfile: SignupNameScreen,
        AuthStatus.onboardingComplete: OnboardingCompleteScreen,
        AuthStatus.sessionExpired: SessionExpiredScreen,
        AuthStatus.loggedIn: DiscoveryScreen,
        AuthStatus.loggedOut: WelcomeScreen,
      };
      for (final MapEntry(key: status, value: screen) in expectations.entries) {
        await pumpApp(
          tester,
          // Discovery itself is open to an incomplete profile, so use a screen
          // that is closed to every unfinished session.
          location: status == AuthStatus.incompleteProfile
              ? AppRoutes.wallet
              : AppRoutes.discover,
          session: status,
        );
        await pumpFrames(tester);
        expect(find.byType(screen), findsOneWidget, reason: '$status');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('an unfinished profile can reach only discovery and its own '
        'completion screen', (tester) async {
      for (final location in [
        AppRoutes.welcome,
        AppRoutes.wallet,
        AppRoutes.likes,
      ]) {
        await pumpApp(
          tester,
          location: location,
          session: AuthStatus.incompleteProfile,
        );
        await pumpFrames(tester);
        expect(
          find.byType(SignupNameScreen),
          findsOneWidget,
          reason: location,
        );
        await tester.pumpWidget(const SizedBox());
      }

      await pumpApp(
        tester,
        location: AppRoutes.discover,
        session: AuthStatus.incompleteProfile,
      );
      await pumpFrames(tester);
      expect(find.byType(DiscoveryScreen), findsOneWidget);
      // Only discovery is open, so the other tabs are not offered.
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('logged in skips the welcome and sign-in screens', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        location: AppRoutes.welcome,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(currentPath(router), AppRoutes.discover);
    });

    testWidgets('logged in can open a protected route', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.wallet,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);
      expect(find.byType(WalletScreen), findsOneWidget);
    });

    testWidgets('splash continues according to the session', (tester) async {
      await pumpApp(tester, session: AuthStatus.loggedIn);
      await tester.pump(AppConstants.splashDuration);
      await pumpFrames(tester);
      expect(find.byType(DiscoveryScreen), findsOneWidget);
    });

    testWidgets('signing out while inside the app returns to welcome', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: AppRoutes.discover,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);
      expect(find.byType(DiscoveryScreen), findsOneWidget);

      containerOf(tester).read(sessionProvider.notifier).signOut();
      await pumpFrames(tester);

      expect(find.byType(DiscoveryScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('You\'ve been signed out.'), findsOneWidget);
    });

    testWidgets('a session that becomes incomplete is redirected live', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: AppRoutes.wallet,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      containerOf(tester)
          .read(sessionProvider.notifier)
          .debugSimulate(AuthStatus.incompleteProfile);
      await pumpFrames(tester);

      expect(find.byType(SignupNameScreen), findsOneWidget);
    });

    testWidgets('account screen: sign out asks first, then leaves the app', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: AppRoutes.account,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);
      expect(find.byType(AccountScreen), findsOneWidget);

      // Cancelling keeps the session.
      await tester.tap(find.text('Sign out'));
      await pumpFrames(tester);
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isTrue);

      // Confirming ends it.
      await tester.tap(find.text('Sign out'));
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Sign out'),
        ),
      );
      await pumpFrames(tester);

      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isFalse);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('account screen: delete account needs confirmation', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: AppRoutes.account,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.tap(find.text('Delete account'));
      await pumpFrames(tester);
      expect(find.textContaining('retention'), findsWidgets);

      final understood = find.text('I understand what deletion means');
      await tester.ensureVisible(understood);
      await tester.pump();
      await tester.tap(understood);
      await pumpFrames(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await pumpFrames(tester);
      expect(find.text('Delete your account?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isTrue);

      await tester.tap(find.widgetWithText(AppButton, 'Continue'));
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Delete account'),
        ),
      );
      await pumpFrames(tester);

      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isFalse);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        find.text('Your account details were deleted from this device.'),
        findsOneWidget,
      );
    });

    testWidgets('offline banner follows the offline flag in the app', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: AppRoutes.wallet,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);
      expect(find.textContaining('You\'re offline'), findsNothing);

      containerOf(tester).read(isOfflineProvider.notifier).setOffline(true);
      await pumpFrames(tester);
      expect(find.textContaining('You\'re offline'), findsOneWidget);

      containerOf(tester).read(isOfflineProvider.notifier).setOffline(false);
      await pumpFrames(tester);
      expect(find.textContaining('You\'re offline'), findsNothing);
    });
  });
}
