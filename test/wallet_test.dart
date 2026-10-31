import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/constants/wallet_rules.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/utils/money.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/core/widgets/interest_chip.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/models/wallet.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/data/repositories/mock_swipe_repository.dart';
import 'package:social_dating/data/repositories/mock_wallet_repository.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/wallet/presentation/transaction_history_screen.dart';
import 'package:social_dating/features/wallet/presentation/wallet_screen.dart';
import 'package:social_dating/features/wallet/presentation/withdrawal_detail_screen.dart';
import 'package:social_dating/features/wallet/presentation/withdrawal_eligibility_screen.dart';
import 'package:social_dating/features/wallet/presentation/withdrawal_request_screen.dart';

import 'helpers/pump_app.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpFrames(tester);
}

MockSwipeRepository womanSwipe({
  required DateTime Function() now,
  required bool Function() isProfileComplete,
  required MockScenario Function() scenario,
}) => MockSwipeRepository(
  latency: Duration.zero,
  now: now,
  isProfileComplete: isProfileComplete,
  scenario: scenario,
  viewerGender: ProfileGender.female,
);

MockWalletRepository earnedWallet(
  int points, {
  required DateTime Function() now,
  required MockScenario Function() scenario,
  required ProfileGender Function() viewerGender,
}) => MockWalletRepository(
  latency: Duration.zero,
  now: now,
  scenario: scenario,
  viewerGender: viewerGender,
)..seedEarnedPoints(points);

MockWalletRepository insufficientWallet({
  required DateTime Function() now,
  required MockScenario Function() scenario,
  required ProfileGender Function() viewerGender,
}) => MockWalletRepository(
  latency: Duration.zero,
  now: now,
  scenario: scenario,
  viewerGender: viewerGender,
)..seedInsufficientEarned();

MockWalletRepository declinedWallet({
  required DateTime Function() now,
  required MockScenario Function() scenario,
  required ProfileGender Function() viewerGender,
}) => MockWalletRepository(
  latency: Duration.zero,
  now: now,
  scenario: scenario,
  viewerGender: viewerGender,
)..seedDeclinedHistory();

void main() {
  group('point conversion', () {
    test('100 points equal NPR 1 and 1 point equals 1 paisa', () {
      expect(WalletRules.pointsPerNpr, 100);
      expect(walletPaisaFromPoints(100), 100);
      expect(formatNpr(walletPaisaFromPoints(100)), 'NPR 1.00');
      expect(formatNpr(walletPaisaFromPoints(10)), 'NPR 0.10');
      expect(formatNpr(walletPaisaFromPoints(500)), 'NPR 5.00');
      expect(formatNpr(walletPaisaFromPoints(1000)), 'NPR 10.00');
      expect(formatNpr(walletPaisaFromPoints(3000)), 'NPR 30.00');
    });

    test('welcome, subscription and swipe amounts live in WalletRules', () {
      expect(WalletRules.welcomeBonusPoints, 1000);
      expect(WalletRules.welcomeBonusWithdrawable, isFalse);
      expect(WalletRules.subscriptionRewardPoints, 3000);
      expect(WalletRules.subscriptionRewardEquivalentPaisa, 3000);
      expect(WalletRules.subscriptionRewardWithdrawable, isFalse);
      expect(WalletRules.swipeSpendPoints, 10);
      expect(WalletRules.minWithdrawalPoints, 500);
      expect(WalletRules.withdrawalFeePoints, 0);
      expect(WalletRules.taxPoints, 0);
      expect(WalletRules.extraFees, isEmpty);
    });
  });

  group('promotional versus earned', () {
    test(
      'welcome and subscription stay promotional and earned stays separate',
      () async {
        final repo = MockWalletRepository(
          latency: Duration.zero,
          now: () => testNow,
          viewerGender: () => ProfileGender.female,
        );
        final summary = await repo.fetchSummary();
        expect(summary.promotionalPoints, 4000);
        expect(summary.earnedPoints, 610);
        expect(summary.availableEarnedPoints, 610);
        expect(
          summary.promotionalPoints + summary.earnedPoints,
          summary.totalPoints,
        );
        expect(
          summary.availableEarnedPoints >= WalletRules.minWithdrawalPoints,
          isTrue,
        );

        final txs = await repo.fetchTransactions();
        expect(
          txs
              .where((tx) => tx.kind == WalletActivityKind.welcomeBonus)
              .single
              .bucket,
          PointBucket.promotional,
        );
        expect(
          txs
              .where((tx) => tx.kind == WalletActivityKind.subscriptionReward)
              .single
              .credits,
          3000,
        );
        expect(
          txs
              .where((tx) => tx.kind == WalletActivityKind.swipeSpend)
              .single
              .credits,
          -10,
        );
      },
    );

    test('promotional points never satisfy the 500-point threshold', () async {
      final repo = MockWalletRepository(
        latency: Duration.zero,
        now: () => testNow,
        viewerGender: () => ProfileGender.female,
      )..seedInsufficientEarned();
      final summary = await repo.fetchSummary();
      expect(summary.promotionalPoints, 4000);
      expect(summary.earnedPoints, 110);
      expect(summary.availableEarnedPoints, 110);
      expect(repo.eligibility().canSubmit, isFalse);
      expect(repo.eligibility().belowMinimum, isTrue);
    });

    test('filters keep promotional and earned buckets apart', () async {
      final repo = MockWalletRepository(
        latency: Duration.zero,
        now: () => testNow,
      );
      final txs = await repo.fetchTransactions();
      final promo = applyWalletFilter(txs, WalletActivityFilter.promotional);
      final earned = applyWalletFilter(txs, WalletActivityFilter.earned);
      final spent = applyWalletFilter(txs, WalletActivityFilter.spent);
      expect(promo.every((tx) => tx.bucket == PointBucket.promotional), isTrue);
      expect(earned.every((tx) => tx.bucket == PointBucket.earned), isTrue);
      expect(spent.every((tx) => !tx.isCredit), isTrue);
      expect(promo, isNotEmpty);
      expect(earned, isNotEmpty);
      expect(spent, isNotEmpty);
    });
  });

  group('withdrawal eligibility', () {
    test('men cannot submit even with enough earned points', () {
      final repo = MockWalletRepository(
        latency: Duration.zero,
        now: () => testNow,
        viewerGender: () => ProfileGender.male,
      );
      final eligibility = repo.eligibility();
      expect(eligibility.earnedAvailable, 610);
      expect(eligibility.eligibleAccount, isFalse);
      expect(eligibility.canSubmit, isFalse);
    });

    test('women can submit at or above 500 earned points', () {
      final repo = MockWalletRepository(
        latency: Duration.zero,
        now: () => testNow,
        viewerGender: () => ProfileGender.female,
      );
      expect(repo.eligibility().canSubmit, isTrue);
    });

    test('a recorded mock request is not marked paid', () async {
      final repo = MockWalletRepository(
        latency: Duration.zero,
        now: () => testNow,
        viewerGender: () => ProfileGender.female,
      );
      final recorded = await repo.submitWithdrawal(
        points: 500,
        confirmed: true,
      );
      expect(recorded.status, WithdrawalStatus.recorded);
      expect(recorded.status, isNot(WithdrawalStatus.declined));
      final after = await repo.fetchSummary();
      expect(after.availableEarnedPoints, 110);
      expect(after.pendingWithdrawalPoints, 500);
      expect(after.promotionalPoints, 4000);
    });
  });

  group('wallet UI', () {
    testWidgets('overview separates promotional and earned NPR equivalents', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.wallet,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(WalletScreen), findsOneWidget);
      expect(find.text('Promotional points'), findsOneWidget);
      expect(find.text('Earned points'), findsOneWidget);
      expect(find.text('4,000 pts'), findsOneWidget);
      expect(find.text('610 pts'), findsOneWidget);
      expect(find.textContaining('NPR 40.00'), findsWidgets);
      expect(find.textContaining('NPR 6.10'), findsWidgets);
      expect(find.textContaining('NPR 46.10'), findsOneWidget);
      expect(
        find.textContaining('not necessarily withdrawable cash'),
        findsWidgets,
      );
    });

    testWidgets('activity filters hide other buckets', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.walletActivity,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(TransactionHistoryScreen), findsOneWidget);
      expect(find.text('Paid swipe'), findsWidgets);
      expect(find.text('Paid message'), findsWidgets);

      await tapVisible(
        tester,
        find.widgetWithText(InterestChip, 'Promotional'),
      );
      expect(find.text('Welcome bonus'), findsWidgets);
      expect(find.text('Subscription reward'), findsWidgets);
      expect(find.text('Paid swipe'), findsNothing);
      expect(find.text('Paid message'), findsNothing);

      await tapVisible(tester, find.widgetWithText(InterestChip, 'Spent'));
      expect(find.text('Paid swipe'), findsWidgets);
      expect(find.text('Paid message'), findsWidgets);
      expect(find.text('Welcome bonus'), findsNothing);
    });

    testWidgets('men do not see the withdrawal request form', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.walletWithdrawRequest,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(WithdrawalRequestScreen), findsOneWidget);
      expect(find.text('Request interface unavailable'), findsOneWidget);
      expect(find.text('Record request'), findsNothing);
    });

    testWidgets('women below 500 earned points see insufficient balance', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.walletWithdraw,
        session: AuthStatus.loggedIn,
        swipeRepository: womanSwipe,
        walletRepository: insufficientWallet,
      );
      await pumpFrames(tester);

      expect(find.byType(WithdrawalEligibilityScreen), findsOneWidget);
      expect(find.text('Insufficient earned points'), findsWidgets);
      expect(find.text('Not enough earned points'), findsOneWidget);
      expect(find.text('Review request'), findsNothing);
    });

    testWidgets('499 earned points stay below the withdrawal threshold', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.walletWithdraw,
        session: AuthStatus.loggedIn,
        swipeRepository: womanSwipe,
        walletRepository:
            ({required now, required scenario, required viewerGender}) =>
                earnedWallet(
                  499,
                  now: now,
                  scenario: scenario,
                  viewerGender: viewerGender,
                ),
      );
      await pumpFrames(tester);

      expect(find.text('Insufficient earned points'), findsWidgets);
      expect(find.text('Review request'), findsNothing);
      expect(find.textContaining('499'), findsWidgets);
    });

    testWidgets('500 earned points open the withdrawal request', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.walletWithdrawRequest,
        session: AuthStatus.loggedIn,
        swipeRepository: womanSwipe,
        walletRepository:
            ({required now, required scenario, required viewerGender}) =>
                earnedWallet(
                  500,
                  now: now,
                  scenario: scenario,
                  viewerGender: viewerGender,
                ),
      );
      await pumpFrames(tester);

      expect(find.byType(WithdrawalRequestScreen), findsOneWidget);
      expect(find.text('Record request'), findsOneWidget);
      expect(find.textContaining('will not be paid'), findsWidgets);
    });

    testWidgets('insufficient earned points hide the request form', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.walletWithdrawRequest,
        session: AuthStatus.loggedIn,
        swipeRepository: womanSwipe,
        walletRepository: insufficientWallet,
      );
      await pumpFrames(tester);
      expect(find.text('Insufficient earned points'), findsOneWidget);
      expect(find.text('Record request'), findsNothing);
    });

    testWidgets('eligible women can record and cancel a withdrawal', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.walletWithdrawRequest,
        session: AuthStatus.loggedIn,
        swipeRepository: womanSwipe,
      );
      await pumpFrames(tester);

      expect(find.byType(WithdrawalRequestScreen), findsOneWidget);
      expect(find.text('Review earned points'), findsOneWidget);
      expect(find.textContaining('will not be paid'), findsWidgets);

      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(
        tester,
        find.widgetWithText(AppButton, 'Record request'),
      );
      expect(find.text('Record this request?'), findsOneWidget);
      await tapVisible(
        tester,
        find.widgetWithText(AppButton, 'Record request').last,
      );

      expect(find.byType(WithdrawalDetailScreen), findsOneWidget);
      expect(find.text('Recorded'), findsWidgets);
      expect(find.textContaining('not submitted to a bank'), findsWidgets);
      expect(find.textContaining('has not been paid'), findsWidgets);
      expect(find.textContaining('was submitted'), findsNothing);
      expect(find.textContaining('has been paid'), findsNothing);

      await tapVisible(tester, find.text('Release hold'));
      await tapVisible(tester, find.text('Release hold').last);
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('declined mock history is never labelled paid', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.walletWithdrawal('mock-wd-declined'),
        session: AuthStatus.loggedIn,
        swipeRepository: womanSwipe,
        walletRepository: declinedWallet,
      );
      await pumpFrames(tester);

      expect(find.text('Declined'), findsOneWidget);
      expect(find.textContaining('Nothing was sent to a bank'), findsWidgets);
      expect(find.text('Paid'), findsNothing);
      expect(find.textContaining('was paid'), findsNothing);
    });
  });
}
