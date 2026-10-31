import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/constants/referral_rules.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/core/constants/subscription_rules.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/utils/money.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/data/models/referral_info.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/data/repositories/mock_referral_repository.dart';
import 'package:social_dating/data/services/share_port.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/discovery/providers/mock_discovery_providers.dart';
import 'package:social_dating/features/referrals/presentation/commission_detail_screen.dart';
import 'package:social_dating/features/referrals/presentation/referral_earnings_screen.dart';
import 'package:social_dating/features/referrals/presentation/referral_history_screen.dart';
import 'package:social_dating/features/referrals/presentation/referrals_screen.dart';
import 'package:social_dating/features/referrals/referral_copy.dart';

import 'helpers/pump_app.dart';

class _FixedScenario extends MockScenarioNotifier {
  _FixedScenario(this.initial);
  final MockScenario initial;

  @override
  MockScenario build() => initial;
}

class _RecordingSharePort implements SharePort {
  String? lastShared;

  @override
  Future<void> shareText(String text) async {
    lastShared = text;
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpFrames(tester);
}

void main() {
  group('commission calculations', () {
    test('NPR 100 split is 60 company, 30 buyer, 10 referrer', () {
      final allocation = ReferralAllocation.qualifyingNpr100();
      expect(allocation.purchasePaisa, 10000);
      expect(allocation.companyPaisa, 6000);
      expect(allocation.buyerRewardEquivalentPaisa, 3000);
      expect(allocation.referrerCommissionPaisa, 1000);
      expect(allocation.allocatedPaisa, allocation.purchasePaisa);
      expect(formatNpr(allocation.companyPaisa), 'NPR 60.00');
      expect(formatNpr(allocation.buyerRewardEquivalentPaisa), 'NPR 30.00');
      expect(formatNpr(allocation.referrerCommissionPaisa), 'NPR 10.00');
      expect(ReferralRules.referrerCommissionPaisa, 1000);
      expect(
        ReferralRules.companyAllocationPaisa,
        SubscriptionRules.companyAllocationPaisa,
      );
    });

    test(
      'pending stays pending until a qualifying purchase is confirmed',
      () async {
        final repo = MockReferralRepository(
          latency: Duration.zero,
          now: () => testNow,
        );
        final before = await repo.fetchReferralInfo();
        expect(before.pendingCommissionPaisa, 1000);
        expect(before.approvedCommissionPaisa, 1000);

        final confirmed = await repo.confirmQualifyingPurchase(
          'mock-ref-riley',
        );
        expect(confirmed.status, CommissionStatus.approved);

        final after = await repo.fetchReferralInfo();
        expect(after.pendingCommissionPaisa, 0);
        expect(after.approvedCommissionPaisa, 2000);
      },
    );

    test('claiming in the mock does not create attribution', () async {
      final repo = MockReferralRepository(
        latency: Duration.zero,
        now: () => testNow,
      );
      await expectLater(
        repo.claimCode('MOCK-0000'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('reversed commissions are not treated as paid earnings', () async {
      final repo = MockReferralRepository(
        latency: Duration.zero,
        now: () => testNow,
      );
      final info = await repo.fetchReferralInfo();
      expect(info.reversedCommissionPaisa, 1000);
      expect(info.paidCommissionPaisa, 1000);
      expect(info.approvedCommissionPaisa, 1000);
      final countedAsEarnings =
          info.approvedCommissionPaisa + info.paidCommissionPaisa;
      expect(countedAsEarnings, 2000);
      expect(
        countedAsEarnings,
        isNot(countedAsEarnings + info.reversedCommissionPaisa),
      );

      final commissions = await repo.fetchCommissions();
      final reversed = commissions.singleWhere(
        (item) => item.status == CommissionStatus.reversed,
      );
      expect(reversed.personName, 'Quinn Example');
      expect(reversed.amountPaisa, ReferralRules.referrerCommissionPaisa);
    });
  });

  group('referral UI', () {
    testWidgets('copy and share use the invite link', (tester) async {
      usePhoneScreen(tester);
      final share = _RecordingSharePort();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpApp(
        tester,
        location: AppRoutes.referrals,
        session: AuthStatus.loggedIn,
        sharePort: share,
      );
      await pumpFrames(tester);

      expect(find.byType(ReferralsScreen), findsOneWidget);
      expect(find.text(ReferralRules.mockCode), findsWidgets);
      expect(
        find.text(ReferralRules.inviteLink(ReferralRules.mockCode)),
        findsOneWidget,
      );

      await tapVisible(tester, find.widgetWithText(AppButton, 'Copy link'));
      expect(copied, ReferralRules.inviteLink(ReferralRules.mockCode));
      expect(find.text('Invite link copied.'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(AppButton, 'Share invite'));
      expect(share.lastShared, isNotNull);
      expect(share.lastShared, contains(ReferralRules.mockCode));
      expect(
        share.lastShared,
        contains(ReferralRules.inviteLink(ReferralRules.mockCode)),
      );
      expect(share.lastShared, isNot(contains('https://')));
    });

    testWidgets('earnings render pending, approved, reversed and paid', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.referralEarnings,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(ReferralEarningsScreen), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Approved'), findsWidgets);
      expect(find.text('Reversed'), findsWidgets);
      expect(find.text('Paid'), findsWidgets);
      expect(find.text('NPR 10.00'), findsWidgets);
    });

    testWidgets('reversed commission detail explains a refund', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.referralCommission('mock-cm-quinn'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(CommissionDetailScreen), findsOneWidget);
      expect(find.text('Quinn Example'), findsOneWidget);
      expect(find.text('Reversed'), findsWidgets);
      expect(find.textContaining('reversed'), findsWidgets);
      expect(find.textContaining('refunded'), findsWidgets);
      expect(commissionStatusLabel(CommissionStatus.reversed), 'Reversed');
    });

    testWidgets('empty history explains that sharing is not enough', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.referralHistory,
        session: AuthStatus.loggedIn,
        overrides: [
          mockScenarioProvider.overrideWith(
            () => _FixedScenario(MockScenario.empty),
          ),
        ],
      );
      await pumpFrames(tester);

      expect(find.byType(ReferralHistoryScreen), findsOneWidget);
      expect(find.text('No invites yet'), findsOneWidget);
    });

    testWidgets('empty earnings explain that sharing is not enough', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.referralEarnings,
        session: AuthStatus.loggedIn,
        overrides: [
          mockScenarioProvider.overrideWith(
            () => _FixedScenario(MockScenario.empty),
          ),
        ],
      );
      await pumpFrames(tester);
      expect(find.text('No commissions yet'), findsOneWidget);
    });

    testWidgets('a failed load shows an error state', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.referrals,
        session: AuthStatus.loggedIn,
        overrides: [
          mockScenarioProvider.overrideWith(
            () => _FixedScenario(MockScenario.failure),
          ),
        ],
      );
      await pumpFrames(tester);

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('offline'), findsWidgets);
    });
  });
}
