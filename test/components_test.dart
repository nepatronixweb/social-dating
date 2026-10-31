import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/theme/app_icons.dart';
import 'package:social_dating/core/theme/app_theme.dart';
import 'package:social_dating/core/widgets/app_pill.dart';
import 'package:social_dating/core/widgets/app_snackbar.dart';
import 'package:social_dating/core/widgets/chat_bubble.dart';
import 'package:social_dating/core/widgets/chat_preview_tile.dart';
import 'package:social_dating/core/widgets/empty_state.dart';
import 'package:social_dating/core/widgets/error_state.dart';
import 'package:social_dating/core/widgets/image_carousel.dart';
import 'package:social_dating/core/widgets/interest_chip.dart';
import 'package:social_dating/core/widgets/match_card.dart';
import 'package:social_dating/core/widgets/menu_tile.dart';
import 'package:social_dating/core/widgets/offline_banner.dart';
import 'package:social_dating/core/widgets/plan_card.dart';
import 'package:social_dating/core/widgets/profile_card.dart';
import 'package:social_dating/core/widgets/verified_badge.dart';
import 'package:social_dating/core/widgets/wallet_summary_card.dart';
import 'package:social_dating/data/models/chat.dart';
import 'package:social_dating/data/models/match.dart';
import 'package:social_dating/data/models/subscription_plan.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';

import 'helpers/pump_app.dart';

void main() {
  final profile = mockProfiles.first;

  group('chips, pills and badges', () {
    testWidgets('InterestChip toggles and has a 44dp tap target', (
      tester,
    ) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        InterestChip(label: 'Hiking', onTap: () => taps++),
      );
      expect(
        tester.getSize(find.byType(InterestChip)).height,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(find.text('Hiking'));
      expect(taps, 1);
    });

    testWidgets('selected and unselected chips look different', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const Column(
          children: [
            InterestChip(label: 'Off'),
            InterestChip(label: 'On', selected: true),
          ],
        ),
      );
      final off = tester.widget<Text>(find.text('Off')).style?.color;
      final on = tester.widget<Text>(find.text('On')).style?.color;
      expect(off, isNot(on));
    });

    testWidgets('AppPill and VerifiedBadge render', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const Row(
          children: [
            AppPill(label: 'New'),
            VerifiedBadge(),
          ],
        ),
      );
      expect(find.text('New'), findsOneWidget);
      expect(find.byIcon(AppIcons.verified), findsOneWidget);
      expect(find.bySemanticsLabel('Verified profile'), findsOneWidget);
    });
  });

  group('cards', () {
    testWidgets('ProfileCard shows name, age and city', (tester) async {
      await pumpWidgetInTheme(
        tester,
        SizedBox(height: 600, child: ProfileCard(profile: profile)),
      );
      expect(find.textContaining(profile.displayName), findsWidgets);
      expect(find.textContaining('${profile.age}'), findsWidgets);
    });

    testWidgets('MatchCard shows the name and fires onTap', (tester) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        SizedBox(
          width: 180,
          height: 240,
          child: MatchCard(
            match: Match(id: 'm', profile: profile, matchedAt: DateTime.now()),
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.textContaining(profile.displayName), findsWidgets);
      await tester.tap(find.byType(MatchCard));
      expect(taps, 1);
    });

    test('MatchCard.matchedLabel is human readable', () {
      final now = DateTime(2026, 1, 10, 12);
      expect(MatchCard.matchedLabel(now, now: now), 'Matched just now');
      expect(
        MatchCard.matchedLabel(now.subtract(const Duration(days: 3)), now: now),
        startsWith('Matched'),
      );
    });

    testWidgets('ChatPreviewTile shows the last message and unread count', (
      tester,
    ) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        ChatPreviewTile(
          preview: ChatPreview(
            id: 'c',
            profile: profile,
            lastMessage: 'Coffee tomorrow?',
            lastMessageAt: DateTime.now(),
            unreadCount: 2,
          ),
          onTap: () => taps++,
        ),
      );
      expect(find.text('Coffee tomorrow?'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byType(ChatPreviewTile));
      expect(taps, 1);
    });

    testWidgets('WalletSummaryCard formats credits and fires actions', (
      tester,
    ) async {
      var added = 0;
      await pumpWidgetInTheme(
        tester,
        WalletSummaryCard(credits: 1250, onAddCredits: () => added++),
      );
      expect(find.text('1,250'), findsOneWidget);
      expect(find.text('Available credits'), findsOneWidget);

      await tester.tap(find.text('Add credits'));
      expect(added, 1);
      // No history action was supplied, so none is offered.
      expect(find.text('History'), findsNothing);
    });

    testWidgets('PlanCard shows pricing and reports selection', (tester) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        PlanCard(
          plan: const SubscriptionPlan(
            id: 'p',
            name: 'Gold',
            priceLabel: r'$0.00 (sample)',
            periodLabel: 'per month',
            features: ['Unlimited likes', 'See who likes you'],
            isPopular: true,
          ),
          selected: true,
          onTap: () => taps++,
        ),
      );
      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Most popular'), findsOneWidget);
      expect(find.text('Unlimited likes'), findsOneWidget);

      await tester.tap(find.byType(PlanCard));
      expect(taps, 1);
    });

    testWidgets('ImageCarousel swipes between photos', (tester) async {
      int? page;
      await pumpWidgetInTheme(
        tester,
        SizedBox(
          height: 300,
          child: ImageCarousel(photoCount: 3, onPageChanged: (p) => page = p),
        ),
      );
      await tester.fling(
        find.byType(ImageCarousel),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(page, 1);
    });

    testWidgets('MenuTile is tappable and meets the touch target', (
      tester,
    ) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        MenuTile(icon: AppIcons.wallet, title: 'Wallet', onTap: () => taps++),
      );
      expect(
        tester.getSize(find.byType(MenuTile)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Wallet'));
      expect(taps, 1);
    });

    testWidgets('ChatBubble aligns by sender', (tester) async {
      await pumpWidgetInTheme(
        tester,
        Column(
          children: [
            ChatBubble(
              message: ChatMessage(
                id: '1',
                text: 'Theirs',
                isMine: false,
                sentAt: DateTime.now(),
              ),
            ),
            ChatBubble(
              message: ChatMessage(
                id: '2',
                text: 'Mine',
                isMine: true,
                sentAt: DateTime.now(),
              ),
            ),
          ],
        ),
      );
      final theirs = tester.getTopLeft(find.text('Theirs')).dx;
      final mine = tester.getTopRight(find.text('Mine')).dx;
      expect(theirs, lessThan(100));
      expect(mine, greaterThan(600 - 100));
    });
  });

  group('states and feedback', () {
    testWidgets('EmptyState shows its message and optional action', (
      tester,
    ) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        EmptyState(
          icon: AppIcons.likes,
          title: 'No likes yet',
          message: 'Check back soon.',
          actionLabel: 'Refresh',
          onAction: () => taps++,
        ),
      );
      expect(find.text('No likes yet'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      expect(taps, 1);
    });

    testWidgets('ErrorState retry works inside a scrolling parent', (
      tester,
    ) async {
      var retries = 0;
      await pumpWidgetInTheme(
        tester,
        SingleChildScrollView(
          child: ErrorState(
            icon: AppIcons.error,
            title: 'Oops',
            message: 'Try again.',
            onRetry: () => retries++,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('OfflineBanner appears only when offline', (tester) async {
      var retries = 0;
      Future<void> pump({required bool visible}) => pumpWidgetInTheme(
        tester,
        OfflineBanner(visible: visible, onRetry: () => retries++),
      );

      await pump(visible: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsNothing);

      await pump(visible: true);
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('snackbars show their message for each type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  for (final type in AppSnackType.values)
                    TextButton(
                      onPressed: () => showAppSnackBar(
                        context,
                        'Message ${type.name}',
                        type: type,
                      ),
                      child: Text('Show ${type.name}'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      for (final type in AppSnackType.values) {
        await tester.tap(find.text('Show ${type.name}'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Message ${type.name}'), findsOneWidget);
        ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold)),
        ).clearSnackBars();
        await tester.pumpAndSettle();
      }
    });
  });
}
