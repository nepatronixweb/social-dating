import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/constants/message_rules.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/theme/app_icons.dart';
import 'package:social_dating/core/utils/connectivity_provider.dart';
import 'package:social_dating/core/utils/money.dart';
import 'package:social_dating/core/utils/time_format.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/core/widgets/chat_bubble.dart';
import 'package:social_dating/core/widgets/chat_date_separator.dart';
import 'package:social_dating/core/widgets/chat_preview_tile.dart';
import 'package:social_dating/core/widgets/confirmation_dialog.dart';
import 'package:social_dating/core/widgets/skeleton_layouts.dart';
import 'package:social_dating/data/models/chat.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/repositories/mock_matching_repository.dart';
import 'package:social_dating/data/repositories/mock_repository_providers.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/chat/presentation/chat_conversation_screen.dart';
import 'package:social_dating/features/safety/presentation/report_user_screen.dart';
import 'package:social_dating/features/wallet/presentation/wallet_screen.dart';

import 'helpers/pump_app.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpFrames(tester);
}

Future<void> sendPaid(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send message'));
  await pumpFrames(tester);
}

void main() {
  group('word counting and quotes', () {
    test('countEligibleWords ignores empty, punctuation and digits', () {
      expect(countEligibleWords(''), 0);
      expect(countEligibleWords('   '), 0);
      expect(countEligibleWords('Hi'), 1);
      expect(countEligibleWords('See you Friday'), 3);
      expect(countEligibleWords('Hello!!'), 1);
      expect(countEligibleWords('!!!'), 0);
      expect(countEligibleWords('42'), 0);
      expect(countEligibleWords('café time'), 2);
      expect(countEligibleWords('one\ntwo\tthree'), 3);
    });

    test('quotes NPR, points and the 80/20 split from one config file', () {
      expect(MessageRules.paisaPerEligibleWord, 10);
      expect(MessageRules.pointsPerNpr, 100);
      expect(MessageRules.recipientSharePercent, 80);
      expect(MessageRules.platformSharePercent, 20);

      final free = MessageQuote.fromText('See you Friday', senderPays: false);
      expect(free.isPaid, isFalse);
      expect(free.costPaisa, 0);

      final paid = MessageQuote.fromText('See you Friday', senderPays: true);
      expect(paid.eligibleWords, 3);
      expect(paid.costPaisa, 30);
      expect(paid.costPoints, 30);
      expect(formatNpr(paid.costPaisa), 'NPR 0.30');
      expect(formatPoints(paid.costPoints), '30 pts');
      expect(paid.recipientSharePaisa, 24);
      expect(paid.platformSharePaisa, 6);
      expect(
        paid.recipientSharePaisa + paid.platformSharePaisa,
        paid.costPaisa,
      );
    });

    test('chat day labels', () {
      final now = DateTime(2026, 10, 14, 12);
      expect(chatDayLabel(now, now: now), 'Today');
      expect(
        chatDayLabel(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );
      expect(chatDayLabel(DateTime(2026, 10, 12), now: now), '12 Oct 2026');
    });
  });

  group('repository: paid send, retry, mute and hide', () {
    test('refuses unpaid paid-sends and does not deduct', () async {
      var balance = 100;
      final repo = MockMatchingRepository(
        latency: Duration.zero,
        now: () => testNow,
        viewerGender: () => ProfileGender.male,
        mockBalancePaisa: () => balance,
        setMockBalancePaisa: (value) => balance = value,
      );

      final refused = await repo.sendMessage('chat-mock-5', 'See you Friday');
      expect(refused.rejection, MessageRejection.paymentRequired);
      expect(balance, 100);

      final sent = await repo.sendMessage(
        'chat-mock-5',
        'See you Friday',
        confirmedPaid: true,
      );
      expect(sent.recorded, isTrue);
      expect(sent.chargedPaisa, 30);
      expect(balance, 70);
    });

    test('failed sends are stored as failed and never charged', () async {
      var balance = 100;
      final repo = MockMatchingRepository(
        latency: Duration.zero,
        now: () => testNow,
        viewerGender: () => ProfileGender.male,
        mockBalancePaisa: () => balance,
        setMockBalancePaisa: (value) => balance = value,
      );
      repo.messaging.failNextSend = true;

      await expectLater(
        repo.sendMessage('chat-mock-5', 'See you Friday', confirmedPaid: true),
        throwsA(isA<NetworkFailure>()),
      );
      expect(balance, 100);
      final failed = (await repo.fetchMessages('chat-mock-5')).last;
      expect(failed.delivery, MessageDelivery.failed);
      expect(failed.chargedPaisa, 0);

      final retried = await repo.sendMessage(
        'chat-mock-5',
        'See you Friday',
        confirmedPaid: true,
        retryOfId: failed.id,
      );
      expect(retried.recorded, isTrue);
      expect(retried.chargedPaisa, 30);
      expect(balance, 70);
      expect(
        (await repo.fetchMessages('chat-mock-5')).last.delivery,
        MessageDelivery.sent,
      );
    });

    test('mute clears unread and hide removes the preview', () async {
      final repo = MockMatchingRepository(
        latency: Duration.zero,
        now: () => testNow,
      );
      expect(
        (await repo.fetchPreviews())
            .where((p) => p.id == 'chat-mock-5')
            .first
            .unreadCount,
        2,
      );
      await repo.setMuted('chat-mock-5', muted: true);
      final muted = (await repo.fetchPreviews()).firstWhere(
        (p) => p.id == 'chat-mock-5',
      );
      expect(muted.muted, isTrue);
      expect(muted.unreadCount, 0);

      await repo.hideConversation('chat-mock-8');
      expect(
        (await repo.fetchPreviews()).map((p) => p.id),
        isNot(contains('chat-mock-8')),
      );
      expect(await repo.fetchMessages('chat-mock-8'), isNotEmpty);
    });
  });

  group('message bubbles', () {
    testWidgets('incoming and outgoing align, with delivery and retry', (
      tester,
    ) async {
      var retries = 0;
      await pumpWidgetInTheme(
        tester,
        Column(
          children: [
            ChatBubble(
              message: ChatMessage(
                id: '1',
                text: 'Theirs',
                isMine: false,
                sentAt: testNow,
              ),
            ),
            ChatBubble(
              message: ChatMessage(
                id: '2',
                text: 'Mine',
                isMine: true,
                sentAt: testNow,
              ),
            ),
            ChatBubble(
              message: ChatMessage(
                id: '3',
                text: 'Nope',
                isMine: true,
                sentAt: testNow,
                delivery: MessageDelivery.failed,
              ),
              onRetry: () => retries++,
            ),
            ChatDateSeparator(at: testNow, now: testNow),
          ],
        ),
      );

      expect(tester.getTopLeft(find.text('Theirs')).dx, lessThan(100));
      expect(tester.getTopRight(find.text('Mine')).dx, greaterThan(500));
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.text('Failed · Retry'));
      expect(retries, 1);
    });
  });

  group('conversation UI', () {
    testWidgets('cost preview shows without a pay confirmation sheet', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextField), 'See you Friday');
      await tester.pump();
      expect(find.textContaining('3 words'), findsOneWidget);
      expect(find.text('Est. NPR 0.30 · 30 pts'), findsOneWidget);
      expect(find.text('Send this paid message?'), findsNothing);
    });

    testWidgets('paid send deducts the quoted mock points immediately', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(
        containerOf(tester).read(mockSwipeRepositoryProvider).balancePaisa,
        100,
      );
      await sendPaid(tester, 'See you Friday');
      expect(find.text('See you Friday'), findsOneWidget);
      expect(find.text('Send this paid message?'), findsNothing);
      expect(
        containerOf(tester).read(mockSwipeRepositoryProvider).balancePaisa,
        70,
      );
    });

    testWidgets('retry after a failed send does not charge the failure', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      containerOf(
        tester,
      ).read(mockMatchingRepositoryProvider).messaging.failNextSend = true;
      await sendPaid(tester, 'See you Friday');

      expect(find.text('Failed · Retry'), findsOneWidget);
      expect(
        containerOf(tester).read(mockSwipeRepositoryProvider).balancePaisa,
        100,
      );

      await tester.tap(find.text('Failed · Retry'));
      await pumpFrames(tester);
      expect(find.text('Failed · Retry'), findsNothing);
      expect(find.text('See you Friday'), findsOneWidget);
      expect(
        containerOf(tester).read(mockSwipeRepositoryProvider).balancePaisa,
        70,
      );
    });

    testWidgets('loading shows skeletons on the conversation list', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chat,
        session: AuthStatus.loggedIn,
        matchingLatency: const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonList), findsOneWidget);
      await pumpFrames(tester, const Duration(seconds: 2));
      expect(find.byType(SkeletonList), findsNothing);
    });

    testWidgets('block and report are available from the conversation menu', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final router = await pumpApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Conversation options'));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Report'));
      expect(find.byType(ReportUserScreen), findsOneWidget);

      router.go(AppRoutes.chatConversation('chat-mock-5'));
      await pumpFrames(tester);
      await tester.tap(find.byTooltip('Conversation options'));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Block'));
      await tapVisible(
        tester,
        find.descendant(
          of: find.byType(AppConfirmationDialog),
          matching: find.widgetWithText(AppButton, 'Block'),
        ),
      );
      expect(find.byType(ChatConversationScreen), findsNothing);
      expect(
        (await containerOf(
          tester,
        ).read(mockMatchingRepositoryProvider).fetchPreviews()).map(
          (p) => p.id,
        ),
        isNot(contains('chat-mock-5')),
      );
    });

    testWidgets('composer rides above the keyboard', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      final before = tester
          .getTopLeft(find.byKey(const Key('chat-composer')))
          .dy;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      await tester.pump();
      final after = tester
          .getTopLeft(find.byKey(const Key('chat-composer')))
          .dy;
      expect(after, lessThan(before - 100));
    });

    testWidgets('search filters conversations', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chat,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.byType(ChatPreviewTile), findsNWidgets(3));
      await tester.enterText(find.byType(TextFormField), 'Morgan');
      await tester.pump();
      expect(find.byType(ChatPreviewTile), findsOneWidget);
      expect(find.text('Morgan Fake'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'zzzz');
      await tester.pump();
      expect(find.text('No conversations match'), findsOneWidget);
    });

    testWidgets('date separators, typing and unread appear', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chat,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);
      expect(
        find.descendant(
          of: find.byType(ChatPreviewTile),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.text('Typing...'), findsOneWidget);

      await tester.tap(find.text('Morgan Fake'));
      await pumpFrames(tester);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('offline blocks send and hide asks first', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      containerOf(tester).read(isOfflineProvider.notifier).setOffline(true);
      await tester.pump();
      expect(find.text("You're offline"), findsWidgets);

      await tester.enterText(find.byType(TextField), 'Hi there');
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, AppIcons.send))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('Conversation options'));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Hide conversation'));
      expect(find.text('Hide this conversation?'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(AppButton, 'Hide'));
      expect(
        (await containerOf(
          tester,
        ).read(mockMatchingRepositoryProvider).fetchPreviews()).map(
          (p) => p.id,
        ),
        isNot(contains('chat-mock-5')),
      );
    });

    testWidgets('insufficient mock credit is not charged', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);
      containerOf(tester).read(mockSwipeRepositoryProvider).balancePaisa = 5;

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await pumpFrames(tester);
      expect(find.text('Not enough balance'), findsOneWidget);
      await tapVisible(tester, find.text('Open wallet'));
      expect(find.byType(WalletScreen), findsOneWidget);
      expect(
        containerOf(tester).read(mockSwipeRepositoryProvider).balancePaisa,
        5,
      );
    });

    testWidgets('sample photo attach shows a local preview', (tester) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-21'),
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Attach sample photo'));
      await pumpFrames(tester);
      expect(find.text('Sample photos'), findsOneWidget);
      await tester.tap(find.byType(Image).first);
      await pumpFrames(tester);
      expect(find.byTooltip('Remove photo'), findsOneWidget);
    });
  });
}
