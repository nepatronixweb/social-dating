import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/constants/subscription_rules.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/utils/money.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/core/widgets/plan_card.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/models/subscription_plan.dart';
import 'package:social_dating/data/repositories/mock_repository_providers.dart';
import 'package:social_dating/data/repositories/mock_subscription_repository.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/subscription/presentation/checkout_screen.dart';
import 'package:social_dating/features/subscription/presentation/payment_status_screen.dart';
import 'package:social_dating/features/subscription/presentation/plan_detail_screen.dart';

import 'helpers/pump_app.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpFrames(tester);
}

void main() {
  group('amount calculation', () {
    test('standard NPR 100 quote is 3,000 points and NPR 30 equivalent', () {
      final plan = MockSubscriptionRepository.checkoutPlan;
      final quote = PurchaseQuote.of(plan: plan, referralLinked: false);
      expect(quote.pricePaisa, 10000);
      expect(quote.amountDuePaisa, 10000);
      expect(formatNpr(quote.amountDuePaisa), 'NPR 100.00');
      expect(quote.buyerPoints, 3000);
      expect(quote.buyerPointsEquivalentPaisa, 3000);
      expect(formatNpr(quote.buyerPointsEquivalentPaisa), 'NPR 30.00');
      expect(quote.referralCommissionPaisa, 0);
      expect(quote.companyAllocationPaisa, 0);
      expect(quote.taxPaisa, 0);
      expect(quote.fees, isEmpty);
      expect(quote.pointsWithdrawable, isFalse);
      expect(quote.hasProviderCharges, isFalse);
    });

    test('referral-linked NPR 100 adds NPR 10 and NPR 60', () {
      final plan = MockSubscriptionRepository.checkoutPlan;
      final quote = PurchaseQuote.of(plan: plan, referralLinked: true);
      expect(quote.amountDuePaisa, 10000);
      expect(quote.buyerPoints, 3000);
      expect(quote.referralCommissionPaisa, 1000);
      expect(quote.companyAllocationPaisa, 6000);
      expect(formatNpr(quote.referralCommissionPaisa), 'NPR 10.00');
      expect(formatNpr(quote.companyAllocationPaisa), 'NPR 60.00');
      expect(
        quote.buyerPointsEquivalentPaisa +
            quote.referralCommissionPaisa +
            quote.companyAllocationPaisa,
        quote.pricePaisa,
      );
    });

    test('rules live in one configuration file', () {
      expect(SubscriptionRules.pricePaisa, 10000);
      expect(SubscriptionRules.minPricePaisa, 1000);
      expect(SubscriptionRules.buyerPoints, 3000);
      expect(SubscriptionRules.promotionalPointsWithdrawable, isFalse);
      expect(SubscriptionRules.taxPaisa, 0);
      expect(SubscriptionRules.extraFees, isEmpty);
      expect(SubscriptionRules.standardPlanRecurring, isFalse);
      expect(SubscriptionRules.monthlyPlanRecurring, isTrue);
    });

    test('custom amounts scale the 30 / 10 / 60 split', () {
      final plan = MockSubscriptionRepository.checkoutPlan;
      final quote = PurchaseQuote.of(
        plan: plan,
        referralLinked: true,
        amountPaisa: 2500,
      );
      expect(quote.pricePaisa, 2500);
      expect(quote.buyerPoints, 750);
      expect(quote.referralCommissionPaisa, 250);
      expect(quote.companyAllocationPaisa, 1500);
      expect(
        quote.buyerPointsEquivalentPaisa +
            quote.referralCommissionPaisa +
            quote.companyAllocationPaisa,
        quote.pricePaisa,
      );
    });

    test('amounts below NPR 10 are refused', () {
      final repo = MockSubscriptionRepository(latency: Duration.zero);
      expect(
        () => repo.quote(
          planId: SubscriptionRules.standardPlanId,
          referralLinked: false,
          amountPaisa: 900,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('female, LGBTQ+ and other accounts cannot start checkout', () async {
      for (final gender in [
        ProfileGender.female,
        ProfileGender.lgbtq,
        ProfileGender.other,
      ]) {
        final repo = MockSubscriptionRepository(
          latency: Duration.zero,
          now: () => testNow,
          viewerGender: () => gender,
        );
        expect((await repo.fetchActive())?.complimentary, isTrue);
        expect(
          () => repo.quote(
            planId: SubscriptionRules.standardPlanId,
            referralLinked: false,
          ),
          throwsA(isA<ValidationFailure>()),
        );
        await expectLater(
          repo.submitCheckout(
            planId: SubscriptionRules.standardPlanId,
            referralLinked: false,
            methodId: 'card',
            confirmed: true,
          ),
          throwsA(isA<ValidationFailure>()),
        );
      }
    });
  });

  group('repository', () {
    test('failed and cancelled outcomes never activate membership', () async {
      final repo = MockSubscriptionRepository(
        latency: Duration.zero,
        now: () => testNow,
      );
      final failed = await repo.submitCheckout(
        planId: SubscriptionRules.standardPlanId,
        referralLinked: false,
        methodId: 'card',
        confirmed: true,
      );
      await repo.resolvePurchase(failed.id, PaymentOutcome.failed);
      expect(await repo.fetchActive(), isNull);

      final cancelled = await repo.submitCheckout(
        planId: SubscriptionRules.standardPlanId,
        referralLinked: false,
        methodId: 'card',
        confirmed: true,
      );
      await repo.resolvePurchase(cancelled.id, PaymentOutcome.cancelled);
      expect(await repo.fetchActive(), isNull);

      final ok = await repo.submitCheckout(
        planId: SubscriptionRules.standardPlanId,
        referralLinked: true,
        methodId: 'esewa',
        confirmed: true,
      );
      final done = await repo.resolvePurchase(ok.id, PaymentOutcome.succeeded);
      expect(done.outcome, PaymentOutcome.succeeded);
      final active = await repo.fetchActive();
      expect(active?.plan.id, SubscriptionRules.standardPlanId);
      expect(active?.isRecurring, isFalse);
    });
  });

  group('subscription UI', () {
    testWidgets('amount-only purchase opens the detail', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.subscription,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(PlanCard), findsNothing);
      expect(find.text('Premium Monthly'), findsNothing);
      expect(find.text('Most popular'), findsNothing);
      expect(find.text('Amount (NPR)'), findsOneWidget);
      await tapVisible(tester, find.text('Review purchase'));
      expect(find.byType(PlanDetailScreen), findsOneWidget);
      expect(find.text('Review standard purchase'), findsOneWidget);
    });

    testWidgets('a custom amount above NPR 10 opens that quote', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.subscription,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextField), '50');
      await tester.pump();
      await tapVisible(tester, find.text('Review purchase'));
      expect(find.byType(PlanDetailScreen), findsOneWidget);
      expect(find.text('NPR 50.00'), findsWidgets);
      expect(find.text('1,500 pts'), findsWidgets);
    });

    testWidgets('referral purchase review shows commission and company share', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.subscriptionCheckout(
          planId: SubscriptionRules.standardPlanId,
          referral: true,
        ),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(find.text('Referral-linked review'), findsOneWidget);
      expect(find.text('NPR 100.00'), findsWidgets);
      expect(find.text('3,000 pts'), findsOneWidget);
      expect(find.text('NPR 30.00'), findsOneWidget);
      expect(find.text('NPR 10.00'), findsOneWidget);
      expect(find.text('NPR 60.00'), findsOneWidget);
      expect(find.text('Direct referral commission'), findsOneWidget);
      expect(find.text('Company allocation'), findsOneWidget);
      expect(find.textContaining('not withdrawable'), findsWidgets);
    });

    testWidgets('pending, failure and success follow the chosen outcome', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final router = await pumpApp(
        tester,
        location: AppRoutes.subscriptionPlan(SubscriptionRules.standardPlanId),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tapVisible(tester, find.text('Review standard purchase'));
      await tapVisible(tester, find.text('Choose a payment method'));
      await tapVisible(tester, find.text('Khalti'));
      await tapVisible(tester, find.text('Confirm purchase'));

      expect(find.byType(PaymentStatusScreen), findsOneWidget);
      expect(find.text('Waiting on payment'), findsOneWidget);

      await tapVisible(tester, find.text('Mark as failed'));
      expect(find.text('Purchase failed'), findsOneWidget);
      expect(
        await containerOf(
          tester,
        ).read(mockSubscriptionRepositoryProvider).fetchActive(),
        isNull,
      );

      router.go(
        AppRoutes.subscriptionPay(planId: SubscriptionRules.standardPlanId),
      );
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Confirm purchase'));
      await tapVisible(tester, find.text('Mark as succeeded'));
      expect(find.text('Purchase succeeded'), findsOneWidget);
      expect(
        (await containerOf(
          tester,
        ).read(mockSubscriptionRepositoryProvider).fetchActive())?.plan.id,
        SubscriptionRules.standardPlanId,
      );
    });

    testWidgets('male likes still offer Premium', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.likes,
        session: AuthStatus.loggedIn,
        gender: ProfileGender.male,
      );
      await pumpFrames(tester);
      expect(find.text('Explore Premium'), findsOneWidget);
    });

    testWidgets('female likes do not offer Premium checkout', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.likes,
        session: AuthStatus.loggedIn,
        gender: ProfileGender.female,
      );
      await pumpFrames(tester);
      expect(find.text('Explore Premium'), findsNothing);
    });

    testWidgets('female accounts see included Premium instead of checkout', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.subscription,
        session: AuthStatus.loggedIn,
        gender: ProfileGender.female,
      );
      await pumpFrames(tester);

      expect(find.text('Included with your account'), findsWidgets);
      expect(find.text('Review selected plan'), findsNothing);
      expect(find.text('Go Premium'), findsNothing);
      expect(find.text('Amount (NPR)'), findsNothing);
    });

    testWidgets('LGBTQ+ checkout routes stay on included Premium', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.subscriptionCheckout(
          planId: SubscriptionRules.standardPlanId,
        ),
        session: AuthStatus.loggedIn,
        gender: ProfileGender.lgbtq,
      );
      await pumpFrames(tester);

      expect(find.text('Included with your account'), findsWidgets);
      expect(find.text('Choose a payment method'), findsNothing);
    });

    testWidgets('duplicate confirm taps create one pending purchase', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.subscriptionPay(
          planId: SubscriptionRules.standardPlanId,
        ),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      final confirm = find.widgetWithText(AppButton, 'Confirm purchase');
      await tester.tap(confirm);
      await tester.tap(confirm);
      await pumpFrames(tester);

      expect(find.text('Waiting on payment'), findsOneWidget);
      expect(
        (await containerOf(
          tester,
        ).read(mockSubscriptionRepositoryProvider).fetchHistory()).length,
        1,
      );
    });
  });
}
