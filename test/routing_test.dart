import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/constants/app_constants.dart';
import 'package:social_dating/core/routing/app_router.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/widgets/brand_mark.dart';
import 'package:social_dating/features/auth/presentation/phone_screen.dart';
import 'package:social_dating/features/onboarding/presentation/splash_screen.dart';
import 'package:social_dating/features/onboarding/presentation/welcome_screen.dart';
import 'package:social_dating/features/settings/presentation/design_system_preview_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  group('routing', () {
    testWidgets('app starts on the splash screen', (tester) async {
      await pumpApp(tester);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(BrandMark), findsOneWidget);
      final mark = tester.widget<Image>(
        find.descendant(
          of: find.byType(BrandMark),
          matching: find.byType(Image),
        ),
      );
      expect((mark.image as AssetImage).assetName, BrandMark.assetPath);
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(
        find.textContaining('Find meaningful connections'),
        findsOneWidget,
      );
      expect(find.textContaining('REAL PEOPLE'), findsOneWidget);

      // Let the splash timer finish so no timers are pending.
      await tester.pump(AppConstants.splashDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('splash navigates to welcome after its duration', (
      tester,
    ) async {
      final router = await pumpApp(tester);

      await tester.pump(
        AppConstants.splashDuration - const Duration(milliseconds: 100),
      );
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.welcome,
      );
    });

    testWidgets('welcome screen shows primary actions', (tester) async {
      await pumpApp(tester, location: AppRoutes.welcome);
      await tester.pumpAndSettle();

      expect(find.text('Create account'), findsNothing);
      expect(find.text('Log in'), findsOneWidget);
    });

    testWidgets('welcome "Log in" opens the phone screen', (tester) async {
      final router = await pumpApp(tester, location: AppRoutes.welcome);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneScreen), findsOneWidget);
      expect(currentPath(router), AppRoutes.authPhone);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('unknown route renders the not-found error screen', (
      tester,
    ) async {
      await pumpApp(tester, location: '/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(find.text('Page not found'), findsOneWidget);

      await tester.tap(find.text('Go to start'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('debug design preview route is registered in debug builds', (
      tester,
    ) async {
      await pumpApp(tester, location: AppRoutes.designPreview);
      // Skeletons animate forever, so avoid pumpAndSettle here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DesignSystemPreviewScreen), findsOneWidget);
      expect(find.textContaining('MOCK DATA'), findsOneWidget);
    });
  });

  group('responsive & accessibility', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'welcome has no overflow on a small phone at ${scale}x text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);

          await pumpApp(tester, location: AppRoutes.welcome);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Log in'), findsOneWidget);
        },
      );
    }

    testWidgets('welcome has no overflow in landscape', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(tester, location: AppRoutes.welcome);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme renders the welcome screen', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.welcome,
        prefs: {'pref.theme_mode': 'dark'},
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(WelcomeScreen));
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });
}
