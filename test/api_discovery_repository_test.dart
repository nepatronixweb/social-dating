import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/data/api/auth_paths.dart';
import 'package:social_dating/data/api/chat_paths.dart';
import 'package:social_dating/data/api/discovery_paths.dart';
import 'package:social_dating/data/api/matching_paths.dart';
import 'package:social_dating/data/api/notification_paths.dart';
import 'package:social_dating/data/api/photo_paths.dart';
import 'package:social_dating/data/api/wallet_paths.dart';
import 'package:social_dating/data/models/app_notification.dart';
import 'package:social_dating/data/models/chat.dart';
import 'package:social_dating/data/models/discovery_filters.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/models/swipe.dart';
import 'package:social_dating/data/models/wallet.dart';
import 'package:social_dating/data/repositories/api_photo_repository.dart';
import 'package:social_dating/data/repositories/api_repositories.dart';
import 'package:social_dating/data/repositories/api_swipe_repository.dart';
import 'package:social_dating/data/services/api_client.dart';
import 'package:social_dating/data/services/token_storage.dart';

void main() {
  late MemoryTokenStorage tokens;
  late _ScriptedAdapter adapter;
  late ApiSwipeRepository swipes;
  late ApiMatchingRepository matches;
  late ApiWalletRepository wallet;
  late ApiPhotoRepository photos;
  late ApiNotificationRepository inbox;

  setUp(() {
    tokens = MemoryTokenStorage();
    adapter = _ScriptedAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://discovery.test'))
      ..httpClientAdapter = adapter;
    final client = ApiClient(
      dio: dio,
      isNetworkEnabled: () => true,
      tokens: tokens,
    );
    swipes = ApiSwipeRepository(client: client, tokens: tokens);
    matches = ApiMatchingRepository(client: client, tokens: tokens);
    wallet = ApiWalletRepository(client: client, tokens: tokens);
    photos = ApiPhotoRepository(client: client, tokens: tokens);
    inbox = ApiNotificationRepository(client: client, tokens: tokens);
  });

  Map<String, Object?> profileJson({
    String id = '11111111-1111-1111-1111-111111111111',
    String displayName = 'Asha',
  }) => {
    'id': id,
    'displayName': displayName,
    'age': 28,
    'city': 'Kathmandu',
    'bio': 'Hikes on Saturday.',
    'interests': ['Hiking', 'Coffee', 'Film'],
    'isVerified': false,
    'isOnline': false,
    'photoCount': 0,
    'distanceKm': null,
    'occupation': null,
    'gender': 'woman',
    'lookingFor': null,
    'photoUrls': <String>[],
  };

  Map<String, Object?> quotaJson({
    bool profileComplete = true,
    int previewUsed = 0,
    int dailyUsed = 0,
    int? freeDailyLimit = 20,
  }) => {
    'profileComplete': profileComplete,
    'previewUsed': previewUsed,
    'dailyUsed': dailyUsed,
    'freeDailyLimit': freeDailyLimit,
    'balancePaisa': 0,
    'pricePaisa': 10,
    'dayKey': '2026-10-29',
    'resetsAt': '2026-10-29T18:15:00.000Z',
  };

  Map<String, Object?> accountJson() => {
    'id': 'acc-1',
    'termsAccepted': true,
    'isAgeEligible': true,
    'displayName': 'Ada',
  };

  Map<String, Object?> sessionJson({
    String access = 'access-2',
    String refresh = 'refresh-2',
  }) => {
    'account': accountJson(),
    'accessToken': access,
    'refreshToken': refresh,
    'expiresAt': '2026-10-29T12:00:00.000Z',
  };

  test('fetchDeck uses the confirmed path and keeps a null distance', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(DiscoveryApiPaths.candidates, (options) {
      expect(options.method, 'GET');
      expect(options.headers['Authorization'], 'Bearer access-1');
      expect(options.queryParameters, {
        'minAge': 18,
        'maxAge': 60,
        'showMe': 'everyone',
        'verifiedOnly': false,
      });
      return _json(200, {
        'items': [profileJson()],
      });
    });

    final deck = await swipes.fetchDeck(
      const DiscoveryFilters(maxDistanceKm: 10),
    );
    expect(deck, hasLength(1));
    expect(deck.single.displayName, 'Asha');
    expect(deck.single.distanceKm, isNull);
    expect(deck.single.gender, ProfileGender.female);
    expect(deck.single.photoCount, 3);
    expect(adapter.remaining, 0);
  });

  test('fetchQuota reads Nepal-day fields', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(DiscoveryApiPaths.quota, (options) {
      expect(options.method, 'GET');
      return _json(200, quotaJson());
    });

    final quota = await swipes.fetchQuota();
    expect(quota.profileComplete, isTrue);
    expect(quota.freeDailyLimit, 20);
    expect(quota.balancePaisa, 0);
    expect(quota.pricePaisa, 10);
    expect(quota.dayKey, '2026-10-29');
  });

  test('swipe posts left or right and can return a match', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(DiscoveryApiPaths.swipes, (options) {
      expect(options.method, 'POST');
      expect(options.data, {
        'profileId': '11111111-1111-1111-1111-111111111111',
        'direction': 'right',
        'confirmedPaid': false,
      });
      return _json(200, {
        'quota': quotaJson(dailyUsed: 1),
        'matchedProfile': profileJson(),
        'chargedPaisa': 0,
        'rejection': null,
      });
    });

    final outcome = await swipes.swipe(
      '11111111-1111-1111-1111-111111111111',
      SwipeDirection.right,
      confirmedPaid: false,
    );
    expect(outcome.recorded, isTrue);
    expect(outcome.matchedProfile?.displayName, 'Asha');
    expect(outcome.chargedPaisa, 0);
    expect(outcome.quota.dailyUsed, 1);
  });

  test('undo treats 204 as nothing to undo', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(DiscoveryApiPaths.undo, (options) {
      expect(options.method, 'POST');
      return _empty(204);
    });

    expect(await swipes.undoLast(), isNull);
  });

  test('a 401 refreshes once and persists the new tokens', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'old-refresh',
    );
    adapter.queue(DiscoveryApiPaths.quota, (options) {
      expect(options.headers['Authorization'], 'Bearer access-1');
      return _json(401, {
        'title': 'Please sign in again.',
        'detail': 'The session is no longer valid.',
      });
    });
    adapter.queue(AuthApiPaths.refresh, (options) {
      expect(options.data, {'refreshToken': 'old-refresh'});
      return _json(200, sessionJson());
    });
    adapter.queue(DiscoveryApiPaths.quota, (options) {
      expect(options.headers['Authorization'], 'Bearer access-2');
      return _json(200, quotaJson());
    });

    final quota = await swipes.fetchQuota();
    expect(quota.dayKey, '2026-10-29');
    expect(await tokens.readAccessToken(), 'access-2');
    expect(await tokens.readRefreshToken(), 'refresh-2');
  });

  test('fetchMatches reads the confirmed list', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(DiscoveryApiPaths.matches, (options) {
      expect(options.method, 'GET');
      return _json(200, {
        'items': [
          {
            'id': '22222222-2222-2222-2222-222222222222',
            'profile': profileJson(),
            'matchedAt': '2026-10-29T06:00:00.000Z',
            'isNew': true,
            'lastActiveAt': null,
            'conversationId': '22222222-2222-2222-2222-222222222222',
          },
        ],
      });
    });

    final items = await matches.fetchMatches();
    expect(items, hasLength(1));
    expect(items.single.profile.displayName, 'Asha');
    expect(items.single.isNew, isTrue);
    expect(items.single.chatId, '22222222-2222-2222-2222-222222222222');
  });

  test('fetchLikesReceived reads nested public profiles', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(MatchingApiPaths.received, (options) {
      expect(options.method, 'GET');
      return _json(200, {
        'items': [
          {'profile': profileJson(), 'likedAt': '2026-10-29T06:00:00.000Z'},
        ],
      });
    });

    final items = await matches.fetchLikesReceived();
    expect(items.single.profile.displayName, 'Asha');
  });

  test('likeBack posts the confirmed path and can create a match', () async {
    const id = '11111111-1111-1111-1111-111111111111';
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(MatchingApiPaths.likeBack(id), (options) {
      expect(options.method, 'POST');
      return _json(200, {
        'match': {
          'id': '22222222-2222-2222-2222-222222222222',
          'profile': profileJson(),
          'matchedAt': '2026-10-29T06:00:00.000Z',
          'isNew': true,
        },
        'created': true,
      });
    });

    final outcome = await matches.likeBack(id);
    expect(outcome.created, isTrue);
    expect(outcome.match?.profile.displayName, 'Asha');
  });

  test('decline, withdraw, unmatch and block use 204', () async {
    const id = '11111111-1111-1111-1111-111111111111';
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(MatchingApiPaths.decline(id), (options) {
      expect(options.method, 'POST');
      return _empty(204);
    });
    adapter.queue(MatchingApiPaths.withdraw(id), (options) {
      expect(options.method, 'DELETE');
      return _empty(204);
    });
    adapter.queue(MatchingApiPaths.unmatch(id), (options) {
      expect(options.method, 'DELETE');
      return _empty(204);
    });
    adapter.queue(MatchingApiPaths.block(id), (options) {
      expect(options.method, 'POST');
      return _empty(204);
    });

    await matches.declineLike(id);
    await matches.withdrawLike(id);
    await matches.unmatch(id);
    await matches.block(id);
    expect(adapter.remaining, 0);
  });

  test('quote is local and does not invent a charge', () {
    final quote = matches.quote('Hello there');
    expect(quote.senderPays, isFalse);
    expect(quote.costPaisa, 0);
    expect(matches.mockBalancePaisa, 0);
  });

  test(
    'chat list, thread, send, read, mute and hide use confirmed paths',
    () async {
      const id = '22222222-2222-2222-2222-222222222222';
      await tokens.writeSession(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );
      adapter.queue(ChatApiPaths.list, (options) {
        expect(options.method, 'GET');
        return _json(200, {
          'items': [
            {
              'id': id,
              'profile': profileJson(),
              'lastMessage': 'Hello Asha',
              'lastMessageAt': '2026-10-29T06:00:00.000Z',
              'unreadCount': 1,
              'muted': false,
              'isTyping': false,
            },
          ],
        });
      });
      adapter.queue(ChatApiPaths.messages(id), (options) {
        expect(options.method, 'GET');
        return _json(200, {
          'items': [
            {
              'id': '33333333-3333-3333-3333-333333333333',
              'text': 'Hello Asha',
              'isMine': true,
              'sentAt': '2026-10-29T06:00:00.000Z',
              'delivery': 'sent',
              'chargedPaisa': 0,
              'eligibleWordCount': 2,
            },
          ],
        });
      });
      adapter.queue(ChatApiPaths.messages(id), (options) {
        expect(options.method, 'POST');
        expect(options.data, {
          'conversationId': id,
          'text': 'Hello Asha',
          'confirmedPaid': false,
          'imageId': null,
          'retryOfId': null,
        });
        return _json(200, {
          'message': {
            'id': '33333333-3333-3333-3333-333333333333',
            'text': 'Hello Asha',
            'isMine': true,
            'sentAt': '2026-10-29T06:00:00.000Z',
            'delivery': 'sent',
            'chargedPaisa': 0,
            'eligibleWordCount': 2,
          },
          'rejection': null,
          'quote': {
            'eligibleWords': 2,
            'characterCount': 10,
            'costPaisa': 0,
            'senderPays': false,
          },
          'chargedPaisa': 0,
          'balancePaisa': 0,
        });
      });
      adapter.queue(ChatApiPaths.read(id), (options) {
        expect(options.method, 'POST');
        return _empty(204);
      });
      adapter.queue(ChatApiPaths.mute(id), (options) {
        expect(options.method, 'POST');
        expect(options.data, {'muted': true});
        return _empty(204);
      });
      adapter.queue(ChatApiPaths.hide(id), (options) {
        expect(options.method, 'POST');
        return _empty(204);
      });

      final previews = await matches.fetchPreviews();
      expect(previews.single.profile.displayName, 'Asha');
      expect(previews.single.unreadCount, 1);

      final thread = await matches.fetchMessages(id);
      expect(thread.single.text, 'Hello Asha');
      expect(thread.single.isMine, isTrue);

      final sent = await matches.sendMessage(id, 'Hello Asha');
      expect(sent.recorded, isTrue);
      expect(sent.message?.text, 'Hello Asha');
      expect(sent.chargedPaisa, 0);

      await matches.markRead(id);
      await matches.setMuted(id, muted: true);
      await matches.hideConversation(id);
      expect(adapter.remaining, 0);
    },
  );

  test('empty photo-only drafts are refused without a network call', () async {
    final outcome = await matches.sendMessage(
      '22222222-2222-2222-2222-222222222222',
      '   ',
      imageAsset: 'assets/portraits/sample.png',
    );
    expect(outcome.rejection, MessageRejection.empty);
    expect(adapter.remaining, 0);
  });

  test('chat photo upload and image-only send use confirmed paths', () async {
    const chatId = '22222222-2222-2222-2222-222222222222';
    const photoId = '77777777-7777-7777-7777-777777777777';
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(ChatApiPaths.photos(chatId), (options) {
      expect(options.method, 'POST');
      expect(options.data, isA<FormData>());
      return _json(200, {
        'id': photoId,
        'url': '/v1/media/$photoId',
        'sortOrder': 0,
      });
    });
    adapter.queue(ChatApiPaths.messages(chatId), (options) {
      expect(options.method, 'POST');
      expect(options.data, {
        'conversationId': chatId,
        'text': '',
        'confirmedPaid': false,
        'imageId': photoId,
        'retryOfId': null,
      });
      return _json(200, {
        'message': {
          'id': '33333333-3333-3333-3333-333333333333',
          'text': '',
          'isMine': true,
          'sentAt': '2026-10-29T06:00:00.000Z',
          'delivery': 'sent',
          'chargedPaisa': 0,
          'eligibleWordCount': 0,
          'imageUrl': '/v1/media/$photoId',
        },
        'rejection': null,
        'quote': {
          'eligibleWords': 0,
          'characterCount': 0,
          'costPaisa': 0,
          'senderPays': false,
        },
        'chargedPaisa': 0,
        'balancePaisa': 1000,
      });
    });

    final uploaded = await matches.uploadChatPhoto(
      chatId,
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'chat.jpg',
    );
    expect(uploaded.id, photoId);
    expect(matches.attachFromDevice, isTrue);

    final sent = await matches.sendMessage(chatId, '', imageAsset: photoId);
    expect(sent.recorded, isTrue);
    expect(sent.message?.imageAsset, '/v1/media/$photoId');
    expect(adapter.remaining, 0);
  });

  test('wallet summary and ledger use confirmed paths', () async {
    const id = '44444444-4444-4444-4444-444444444444';
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(WalletApiPaths.summary, (options) {
      expect(options.method, 'GET');
      return _json(200, {
        'promotionalPoints': 1000,
        'earnedPoints': 0,
        'pendingWithdrawalPoints': 0,
      });
    });
    adapter.queue(WalletApiPaths.transactions, (options) {
      expect(options.method, 'GET');
      return _json(200, {
        'items': [
          {
            'id': id,
            'title': 'Welcome bonus',
            'points': 1000,
            'occurredAt': '2026-10-29T06:00:00.000Z',
            'bucket': 'promotional',
            'kind': 'welcomeBonus',
            'detail':
                'Promotional welcome points. Not cash and not withdrawable.',
          },
        ],
      });
    });
    adapter.queue(WalletApiPaths.transaction(id), (options) {
      expect(options.method, 'GET');
      return _json(200, {
        'id': id,
        'title': 'Welcome bonus',
        'points': 1000,
        'occurredAt': '2026-10-29T06:00:00.000Z',
        'bucket': 'promotional',
        'kind': 'welcomeBonus',
        'detail': 'Promotional welcome points. Not cash and not withdrawable.',
      });
    });
    adapter.queue(WalletApiPaths.withdrawals, (options) {
      expect(options.method, 'GET');
      return _json(200, {'items': <Object>[]});
    });
    adapter.queue(WalletApiPaths.eligibility, (options) {
      expect(options.method, 'GET');
      return _json(200, {
        'eligibleAccount': true,
        'earnedAvailable': 0,
        'minimumPoints': 500,
        'feePoints': 0,
        'canSubmit': false,
        'explanation':
            'You need at least 500 earned, withdrawable points. Promotional '
            'points never count toward this threshold.',
        'payoutsEnabled': false,
        'isLive': true,
      });
    });

    final summary = await wallet.fetchSummary();
    expect(summary.promotionalPoints, 1000);
    expect(summary.earnedPoints, 0);
    expect(summary.totalPoints, 1000);

    final items = await wallet.fetchTransactions();
    expect(items.single.kind, WalletActivityKind.welcomeBonus);
    expect(items.single.credits, 1000);

    final one = await wallet.fetchTransaction(id);
    expect(one?.title, 'Welcome bonus');
    expect(wallet.eligibility().canSubmit, isFalse);
    expect(await wallet.fetchWithdrawals(), isEmpty);
    final eligibility = await wallet.fetchEligibility();
    expect(eligibility.canSubmit, isFalse);
    expect(eligibility.isLive, isTrue);
    expect(eligibility.payoutsEnabled, isFalse);
    expect(adapter.remaining, 0);
  });

  test('own photos list, upload, reorder and delete', () async {
    const id = '55555555-5555-5555-5555-555555555555';
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(PhotoApiPaths.mine, (options) {
      expect(options.method, 'GET');
      return _json(200, {
        'items': [
          {'id': id, 'url': '/v1/media/$id', 'sortOrder': 0},
        ],
      });
    });
    adapter.queue(PhotoApiPaths.mine, (options) {
      expect(options.method, 'POST');
      expect(options.data, isA<FormData>());
      return _json(200, {
        'id': '66666666-6666-6666-6666-666666666666',
        'url': '/v1/media/66666666-6666-6666-6666-666666666666',
        'sortOrder': 1,
      });
    });
    adapter.queue(PhotoApiPaths.order, (options) {
      expect(options.method, 'PATCH');
      return _empty(204);
    });
    adapter.queue(PhotoApiPaths.one(id), (options) {
      expect(options.method, 'DELETE');
      return _empty(204);
    });

    final listed = await photos.fetchMine();
    expect(listed.single.id, id);
    expect(listed.single.source, '/v1/media/$id');

    final uploaded = await photos.upload(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'a.jpg',
    );
    expect(uploaded.sortOrder, 1);

    await photos.reorder([uploaded.id, id]);
    await photos.delete(id);
    expect(adapter.remaining, 0);
  });

  test('notification list and mark-read use confirmed paths', () async {
    const id = '88888888-8888-8888-8888-888888888888';
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(NotificationApiPaths.list, (options) {
      expect(options.method, 'GET');
      return _json(200, {
        'items': [
          {
            'id': id,
            'type': 'match',
            'title': 'New match',
            'body': 'You and Asha liked each other.',
            'createdAt': '2026-10-29T06:00:00.000Z',
            'isRead': false,
          },
        ],
      });
    });
    adapter.queue(NotificationApiPaths.read(id), (options) {
      expect(options.method, 'POST');
      return _empty(204);
    });
    adapter.queue(NotificationApiPaths.readAll, (options) {
      expect(options.method, 'POST');
      return _empty(204);
    });

    final items = await inbox.fetchNotifications();
    expect(items.single.type, NotificationType.match);
    expect(items.single.isRead, isFalse);
    await inbox.markRead(id);
    await inbox.markAllRead();
    expect(adapter.remaining, 0);
  });
}

ResponseBody _json(int status, Map<String, Object?> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _empty(int status) => ResponseBody.fromString('', status);

typedef _Handler = ResponseBody Function(RequestOptions options);

class _ScriptedAdapter implements HttpClientAdapter {
  final Map<String, List<_Handler>> _handlers = {};

  void queue(String path, _Handler handler, {int times = 1}) {
    _handlers.putIfAbsent(path, () => []).addAll(List.filled(times, handler));
  }

  int get remaining =>
      _handlers.values.fold<int>(0, (sum, list) => sum + list.length);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final queued = _handlers[path];
    if (queued == null || queued.isEmpty) {
      fail('Unexpected ${options.method} $path');
    }
    return queued.removeAt(0)(options);
  }
}
