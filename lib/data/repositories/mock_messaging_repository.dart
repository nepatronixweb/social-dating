// ============================================================================
// MOCK DATA ONLY: in-memory messaging "service"
//
// Conversations, delivery states, mute/hide, typing and paid-word quotes live
// in memory and vanish when the app restarts. NOTHING is sent over the
// network, SignalR is not used, and no real money moves. Owned by
// MockMatchingRepository so unmatch/block still close chats. Nothing outside
// `mock_*` files and the approved seam may import this file
// (test/mock_isolation_test.dart).
// ============================================================================

import 'dart:typed_data';

import '../../core/constants/message_rules.dart';
import '../../core/errors/app_failure.dart';
import '../models/chat.dart';
import '../models/match.dart';
import '../models/profile.dart';
import '../models/profile_photo.dart';
import 'mock_profile_repository.dart';
import 'repository_contracts.dart';

class MockMessagingRepository implements ChatRepository {
  MockMessagingRepository({
    required MockScenario Function() scenario,
    required Duration Function() latency,
    required DateTime Function() now,
    required ProfileGender Function() viewerGender,
    required int Function() balancePaisa,
    required void Function(int) setBalancePaisa,
    required bool Function(String chatId) isChatOpen,
    required List<Match> Function() matches,
  }) : _scenario = scenario,
       _latency = latency,
       _now = now,
       _viewerGender = viewerGender,
       _balancePaisa = balancePaisa,
       _setBalancePaisa = setBalancePaisa,
       _isChatOpen = isChatOpen,
       _matches = matches {
    reset();
  }

  final MockScenario Function() _scenario;
  final Duration Function() _latency;
  final DateTime Function() _now;
  final ProfileGender Function() _viewerGender;
  final int Function() _balancePaisa;
  final void Function(int) _setBalancePaisa;
  final bool Function(String chatId) _isChatOpen;
  final List<Match> Function() _matches;

  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, int> _unread = {};
  final Set<String> _muted = {};
  final Set<String> _hidden = {};
  final Set<String> _typing = {};
  int _counter = 0;
  bool _inFlight = false;

  /// When true, the next send is stored as failed and nothing is deducted.
  bool failNextSend = false;

  static const closedChat = NotFoundFailure(
    'This conversation has ended because the match was removed.',
  );

  /// Restores the starting sample conversations.
  void reset() {
    final now = _now();
    DateTime ago(Duration d) => now.subtract(d);
    failNextSend = false;
    _inFlight = false;
    _counter = 0;
    _muted.clear();
    _hidden.clear();
    _typing
      ..clear()
      ..add(Match.chatIdFor('mock-8'));
    _unread
      ..clear()
      ..[Match.chatIdFor('mock-5')] = 2;
    _messages
      ..clear()
      ..[Match.chatIdFor('mock-5')] = [
        ChatMessage(
          id: 'c5-0',
          text: 'Placeholder: saw your travel photos.',
          isMine: false,
          sentAt: ago(const Duration(days: 1, hours: 2)),
        ),
        ChatMessage(
          id: 'c5-1',
          text: 'Placeholder: hi! Your profile made me smile.',
          isMine: false,
          sentAt: ago(const Duration(hours: 1, minutes: 5)),
        ),
        ChatMessage(
          id: 'c5-2',
          text: 'Placeholder: thank you, same to you.',
          isMine: true,
          sentAt: ago(const Duration(hours: 1)),
        ),
        ChatMessage(
          id: 'c5-3',
          text: 'Placeholder: that sounds like a plan.',
          isMine: false,
          sentAt: ago(const Duration(minutes: 12)),
          imageAsset: 'assets/portraits/avery.jpg',
        ),
      ]
      ..[Match.chatIdFor('mock-8')] = [
        ChatMessage(
          id: 'c8-1',
          text: 'Placeholder: haha, fair enough.',
          isMine: false,
          sentAt: ago(const Duration(hours: 5)),
        ),
      ]
      ..[Match.chatIdFor('mock-9')] = [
        ChatMessage(
          id: 'c9-1',
          text: 'Placeholder: what are you reading?',
          isMine: false,
          sentAt: ago(const Duration(days: 1, hours: 3)),
        ),
      ];
  }

  /// Called when a match is unmatched or blocked.
  void close(String chatId) {
    _messages.remove(chatId);
    _unread.remove(chatId);
    _muted.remove(chatId);
    _hidden.remove(chatId);
    _typing.remove(chatId);
  }

  bool get _senderPays => _viewerGender().paysForExtraSwipesAndWords;

  @override
  MessageQuote quote(String text) =>
      MessageQuote.fromText(text, senderPays: _senderPays);

  @override
  int get mockBalancePaisa => _balancePaisa();

  Future<void> _wait() async {
    final latency = _latency();
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  Future<T> _fetch<T>(T Function() data, T empty) => simulateMockCall(
    scenario: _scenario(),
    latency: _latency(),
    data: data,
    empty: empty,
  );

  Future<T> _change<T>(T Function() change) async {
    await _wait();
    if (_scenario() == MockScenario.failure) throw const NetworkFailure();
    return change();
  }

  String _previewText(ChatMessage last) {
    if (last.text.trim().isNotEmpty) return last.text;
    if (last.hasImage) return 'Photo';
    return '';
  }

  @override
  Future<List<ChatPreview>> fetchPreviews() => _fetch(() {
    final previews = <ChatPreview>[];
    for (final match in _matches()) {
      final chatId = match.chatId;
      if (_hidden.contains(chatId)) continue;
      final messages = _messages[chatId];
      if (messages == null || messages.isEmpty) continue;
      final last = messages.last;
      final muted = _muted.contains(chatId);
      previews.add(
        ChatPreview(
          id: chatId,
          profile: _peerProfileForViewer(match.profile),
          lastMessage: _previewText(last),
          lastMessageAt: last.sentAt,
          unreadCount: muted ? 0 : (_unread[chatId] ?? 0),
          muted: muted,
          isTyping: _typing.contains(chatId),
        ),
      );
    }
    previews.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return previews;
  }, const []);

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    await _wait();
    if (_scenario() == MockScenario.failure) throw const NetworkFailure();
    if (!_isChatOpen(chatId)) throw closedChat;
    if (_scenario() == MockScenario.empty) return const [];
    return [...?_messages[chatId]];
  }

  @override
  Future<SendOutcome> sendMessage(
    String chatId,
    String text, {
    bool confirmedPaid = false,
    String? imageAsset,
    String? retryOfId,
  }) async {
    await _wait();
    if (_scenario() == MockScenario.failure) throw const NetworkFailure();
    if (!_isChatOpen(chatId)) throw closedChat;
    if (_inFlight) {
      return const SendOutcome.rejected(rejection: MessageRejection.empty);
    }
    _inFlight = true;
    try {
      final trimmed = text.trim();
      final asset = imageAsset;
      if (trimmed.isEmpty && asset == null && retryOfId == null) {
        return const SendOutcome.rejected(rejection: MessageRejection.empty);
      }

      final existing = retryOfId == null
          ? null
          : _messages[chatId]?.where((m) => m.id == retryOfId).firstOrNull;
      if (retryOfId != null && existing == null) {
        return const SendOutcome.rejected(rejection: MessageRejection.empty);
      }

      final body = existing?.text ?? trimmed;
      final photo = existing?.imageAsset ?? asset;
      final draftQuote = quote(body);
      if (draftQuote.tooLong) {
        return SendOutcome.rejected(
          rejection: MessageRejection.tooLong,
          quote: draftQuote,
          balancePaisa: mockBalancePaisa,
        );
      }
      if (draftQuote.isPaid && !confirmedPaid) {
        return SendOutcome.rejected(
          rejection: MessageRejection.paymentRequired,
          quote: draftQuote,
          balancePaisa: mockBalancePaisa,
        );
      }
      if (draftQuote.isPaid && mockBalancePaisa < draftQuote.costPaisa) {
        return SendOutcome.rejected(
          rejection: MessageRejection.insufficientFunds,
          quote: draftQuote,
          balancePaisa: mockBalancePaisa,
        );
      }

      final sending =
          existing?.copyWith(
            delivery: MessageDelivery.sending,
            chargedPaisa: 0,
          ) ??
          ChatMessage(
            id: 'local-${++_counter}',
            text: body,
            isMine: true,
            sentAt: _now(),
            delivery: MessageDelivery.sending,
            imageAsset: photo,
            eligibleWordCount: draftQuote.eligibleWords,
          );
      final thread = _messages[chatId] ??= [];
      if (existing == null) {
        thread.add(sending);
      } else {
        final index = thread.indexWhere((m) => m.id == existing.id);
        thread[index] = sending;
      }

      if (failNextSend) {
        failNextSend = false;
        final failed = sending.copyWith(
          delivery: MessageDelivery.failed,
          chargedPaisa: 0,
        );
        final index = thread.indexWhere((m) => m.id == sending.id);
        thread[index] = failed;
        throw const NetworkFailure('Message not sent. Try again.');
      }

      if (draftQuote.isPaid) {
        _setBalancePaisa(mockBalancePaisa - draftQuote.costPaisa);
      }
      final sent = sending.copyWith(
        delivery: MessageDelivery.sent,
        chargedPaisa: draftQuote.costPaisa,
        sentAt: _now(),
      );
      final index = thread.indexWhere((m) => m.id == sending.id);
      thread[index] = sent;
      _typing.remove(chatId);
      return SendOutcome.recorded(
        message: sent,
        chargedPaisa: draftQuote.costPaisa,
        balancePaisa: mockBalancePaisa,
      );
    } finally {
      _inFlight = false;
    }
  }

  @override
  Future<void> markRead(String chatId) => _change(() {
    _unread.remove(chatId);
  });

  @override
  Future<void> setMuted(String chatId, {required bool muted}) => _change(() {
    if (muted) {
      _muted.add(chatId);
      _unread.remove(chatId);
    } else {
      _muted.remove(chatId);
    }
  });

  @override
  Future<void> hideConversation(String chatId) => _change(() {
    _hidden.add(chatId);
  });

  @override
  bool get attachFromDevice => false;

  @override
  Future<ProfilePhoto> uploadChatPhoto(
    String chatId, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    await _wait();
    return ProfilePhoto(
      id: 'chat-photo-${++_counter}',
      source: MessageRules.sampleAttachmentAssets.first,
      sortOrder: 0,
    );
  }

  /// Female / LGBTQ+ / other viewers see a male peer's wallet points in chat.
  Profile _peerProfileForViewer(Profile profile) {
    if (!_viewerGender().canWithdrawAndSetDailyPreference) {
      return profile.copyWith(clearSpendablePoints: true);
    }
    if (profile.gender != ProfileGender.male) {
      return profile.copyWith(clearSpendablePoints: true);
    }
    return profile.copyWith(
      spendablePoints: profile.spendablePoints ?? _mockMalePoints(profile.id),
    );
  }

  static int _mockMalePoints(String id) {
    final seed = id.codeUnits.fold(0, (sum, unit) => sum + unit);
    return 2000 + (seed % 30) * 100;
  }
}
