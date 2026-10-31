import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/errors/api_error_mapper.dart';
import 'package:social_dating/data/api/page.dart';
import 'package:social_dating/data/dto/account_dtos.dart';
import 'package:social_dating/data/dto/auth_dtos.dart';
import 'package:social_dating/data/dto/billing_dtos.dart';
import 'package:social_dating/data/dto/chat_dtos.dart';
import 'package:social_dating/data/dto/match_dtos.dart';
import 'package:social_dating/data/dto/photo_dtos.dart';
import 'package:social_dating/data/dto/profile_dtos.dart';
import 'package:social_dating/data/models/app_notification.dart';
import 'package:social_dating/data/models/chat.dart';
import 'package:social_dating/data/models/matching.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/models/referral_info.dart';
import 'package:social_dating/data/models/subscription_plan.dart';
import 'package:social_dating/data/models/wallet.dart';
import 'package:social_dating/data/dto/typed_values.dart';

Map<String, Object?> profileJson({String id = 'p-1'}) => {
  'id': id,
  'displayName': 'Asha',
  'age': 28,
  'city': 'Kathmandu',
  'bio': 'Hikes on Saturday.',
  'interests': ['Hiking', 'Coffee'],
  'isVerified': true,
  'isOnline': false,
  'photoCount': 3,
  'distanceKm': 4,
  'occupation': 'Designer',
  'gender': 'woman',
  'lookingFor': 'Something lasting',
  'photoUrls': const <String>[],
};

void main() {
  group('typed money and ids', () {
    test('Paisa and Points round-trip as integers', () {
      expect(const Paisa(10000).toJson(), 10000);
      expect(const Points(500).toJson(), 500);
      expect(const ProfileId('p-1').raw, 'p-1');
    });
  });

  group('auth DTOs', () {
    test('account state rejects a private phone field', () {
      expect(
        () => AccountStateDto.fromJson({
          'id': 'acc-1',
          'termsAccepted': true,
          'phone': '+9779841234567',
        }),
        throwsA(isA<JsonFormatException>()),
      );
    });

    test('verify response round-trips without leaking tokens by default', () {
      final json = {
        'account': {
          'id': 'acc-1',
          'termsAccepted': true,
          'isAgeEligible': true,
          'displayName': 'Asha',
        },
        'accessToken': 'secret-access',
        'refreshToken': 'secret-refresh',
        'expiresAt': '2026-10-16T12:00:00.000Z',
      };
      final dto = AuthVerifyResponseDto.fromJson(json);
      expect(dto.account.toDomain().id, 'acc-1');
      expect(dto.accessToken, 'secret-access');
      final public = dto.toJson();
      expect(public.containsKey('accessToken'), isFalse);
      expect(public.containsKey('refreshToken'), isFalse);
      expect(dto.toString(), isNot(contains('secret-access')));
      final withSecrets = dto.toJson(includeSecrets: true);
      expect(withSecrets['accessToken'], 'secret-access');
    });

    test('age submit sends a calendar date, not a timestamp', () {
      expect(SubmitAgeRequestDto(birthDate: DateTime(2000, 1, 15)).toJson(), {
        'birthDate': '2000-01-15',
      });
    });

    test('profile completion sends bio and interests', () {
      expect(
        const CompleteProfileRequestDto(
          displayName: 'Ada',
          bio: 'Hikes on Saturday.',
          interests: ['Hiking', 'Coffee', 'Film'],
          city: 'Kathmandu',
          gender: 'female',
        ).toJson(),
        {
          'displayName': 'Ada',
          'bio': 'Hikes on Saturday.',
          'interests': ['Hiking', 'Coffee', 'Film'],
          'city': 'Kathmandu',
          'gender': 'female',
        },
      );
    });
  });

  group('profile, discovery and swipe DTOs', () {
    test('profile round-trips and maps to the domain model', () {
      final dto = ProfileDto.fromJson(profileJson());
      expect(dto.toJson()['id'], 'p-1');
      final domain = dto.toDomain();
      expect(domain.displayName, 'Asha');
      expect(domain.gender, ProfileGender.female);
      expect(parseProfileGender('man'), ProfileGender.male);
      expect(parseProfileGender('lgbtq'), ProfileGender.lgbtq);
      expect(parseProfileGender('other'), ProfileGender.other);
      expect(domain.city, 'Kathmandu');
      expect(domain.photoUrls, isEmpty);
    });

    test('profile photo URLs map onto the domain model', () {
      final dto = ProfileDto.fromJson({
        ...profileJson(),
        'photoCount': 1,
        'photoUrls': ['/v1/media/abc'],
      });
      final domain = dto.toDomain();
      expect(domain.photoUrls, ['/v1/media/abc']);
      expect(domain.photos, ['/v1/media/abc']);
      expect(domain.photoCount, 1);
    });

    test('photo item round-trips', () {
      const json = {'id': 'photo-1', 'url': '/v1/media/abc', 'sortOrder': 0};
      final dto = PhotoDto.fromJson(json);
      expect(dto.toJson(), json);
      expect(dto.toDomain().source, '/v1/media/abc');
    });

    test('profile rejects exact coordinates', () {
      expect(
        () => ProfileDto.fromJson({...profileJson(), 'latitude': 27}),
        throwsA(isA<JsonFormatException>()),
      );
    });

    test('swipe quota rejects fractional paisa', () {
      expect(
        () => SwipeQuotaDto.fromJson({
          'profileComplete': true,
          'previewUsed': 0,
          'dailyUsed': 3,
          'freeDailyLimit': 10,
          'balancePaisa': 10.5,
          'pricePaisa': 10,
          'dayKey': '2026-10-16',
          'resetsAt': '2026-10-16T18:15:00.000Z',
        }),
        throwsA(isA<JsonFormatException>()),
      );
    });

    test('swipe outcome round-trips a recorded like and charged paisa', () {
      final json = {
        'quota': {
          'profileComplete': true,
          'previewUsed': 0,
          'dailyUsed': 4,
          'freeDailyLimit': 10,
          'balancePaisa': 90,
          'pricePaisa': 10,
          'dayKey': '2026-10-16',
          'resetsAt': '2026-10-16T18:15:00.000Z',
        },
        'matchedProfile': profileJson(id: 'p-2'),
        'chargedPaisa': 10,
        'rejection': null,
      };
      final dto = SwipeOutcomeDto.fromJson(json);
      final domain = dto.toDomain();
      expect(domain.recorded, isTrue);
      expect(domain.chargedPaisa, 10);
      expect(domain.matchedProfile?.id, 'p-2');
      expect(dto.toJson()['chargedPaisa'], 10);
    });
  });

  group('likes, matches and chat DTOs', () {
    test('match and like-outcome round-trip', () {
      final matchJson = {
        'id': 'm-1',
        'profile': profileJson(),
        'matchedAt': '2026-10-16T08:00:00.000Z',
        'isNew': true,
        'lastActiveAt': '2026-10-16T08:05:00.000Z',
      };
      final match = MatchDto.fromJson(matchJson);
      expect(match.toDomain().id, 'm-1');
      expect(match.toDomain().isNew, isTrue);
      final outcome = LikeOutcomeDto.fromJson({
        'match': matchJson,
        'created': true,
      });
      expect(outcome.toDomain().created, isTrue);
      expect(outcome.toDomain().match?.id, 'm-1');
    });

    test('message quote and send outcome use integer paisa', () {
      final quote = MessageQuoteDto.fromJson({
        'eligibleWords': 3,
        'characterCount': 14,
        'costPaisa': 30,
        'senderPays': true,
      });
      expect(quote.toDomain().costPaisa, 30);
      expect(quote.toDomain().eligibleWords, 3);
      final send = SendOutcomeDto.fromJson({
        'message': {
          'id': 'msg-1',
          'text': 'See you Friday',
          'isMine': true,
          'sentAt': '2026-10-16T09:00:00.000Z',
          'delivery': 'sent',
          'chargedPaisa': 30,
          'eligibleWordCount': 3,
        },
        'chargedPaisa': 30,
        'balancePaisa': 70,
      });
      expect(send.toDomain().recorded, isTrue);
      expect(send.toDomain().chargedPaisa, 30);
      expect(send.toDomain().balancePaisa, 70);
      expect(send.toDomain().message?.delivery, MessageDelivery.sent);
    });

    test('message imageUrl maps onto the domain image asset', () {
      final dto = MessageDto.fromJson({
        'id': 'msg-2',
        'text': '',
        'isMine': true,
        'sentAt': '2026-10-29T09:00:00.000Z',
        'delivery': 'sent',
        'imageUrl': '/v1/media/abc',
        'chargedPaisa': 0,
        'eligibleWordCount': 0,
      });
      expect(dto.toDomain().imageAsset, '/v1/media/abc');
      expect(dto.toDomain().hasImage, isTrue);
    });

    test('chat hub event parses message and typing', () {
      final message = ChatPushDto.fromJson({
        'type': 'message',
        'conversationId': 'c-1',
        'message': {
          'id': 'msg-9',
          'text': 'Hello',
          'isMine': false,
          'sentAt': '2026-10-29T09:00:00.000Z',
          'delivery': 'sent',
          'chargedPaisa': 0,
          'eligibleWordCount': 1,
        },
      });
      expect(message.type, 'message');
      expect(message.conversationId, 'c-1');
      expect(message.message?.text, 'Hello');
      expect(message.message?.isMine, isFalse);

      final typing = ChatPushDto.fromJson({
        'type': 'typing',
        'conversationId': 'c-1',
        'typing': true,
      });
      expect(typing.typing, isTrue);
    });
  });

  group('subscription, wallet and referral DTOs', () {
    test('plan and payment status use paisa and PaymentOutcome', () {
      final plan = SubscriptionPlanDto.fromJson({
        'id': 'npr-100',
        'name': 'Premium',
        'pricePaisa': 10000,
        'periodLabel': 'one time',
        'features': ['See who likes you'],
        'isPopular': true,
        'isRecurring': false,
      });
      expect(plan.toDomain().pricePaisa, 10000);
      final status = PaymentStatusDto.fromJson({
        'id': 'pay-1',
        'outcome': 'pending',
        'amountPaisa': 10000,
        'createdAt': '2026-10-16T10:00:00.000Z',
      });
      expect(status.outcome, PaymentOutcome.pending);
      expect(status.amountPaisa.paisa, 10000);
    });

    test('purchase record round-trips', () {
      final json = {
        'id': 'pur-1',
        'plan': {
          'id': 'npr-100',
          'name': 'Premium',
          'pricePaisa': 10000,
          'periodLabel': 'one time',
          'features': ['See who likes you'],
          'isRecurring': false,
        },
        'amountPaisa': 10000,
        'outcome': 'succeeded',
        'createdAt': '2026-10-16T10:00:00.000Z',
        'referralLinked': true,
        'methodId': 'card',
        'methodName': 'Card',
      };
      final dto = PurchaseRecordDto.fromJson(json);
      expect(dto.toDomain().amountPaisa, 10000);
      expect(dto.toDomain().outcome, PaymentOutcome.succeeded);
      expect(dto.toJson()['outcome'], 'succeeded');
    });

    test('active membership can be complimentary', () {
      final dto = ActiveSubscriptionDto.fromJson({
        'plan': {
          'id': 'included',
          'name': 'Included',
          'pricePaisa': 0,
          'periodLabel': 'with your account',
          'features': ['See who likes you'],
          'isRecurring': false,
          'priceLabel': 'Included',
        },
        'startedAt': '2026-10-16T10:00:00.000Z',
        'complimentary': true,
      });
      expect(dto.toDomain().complimentary, isTrue);
      expect(dto.toDomain().plan.id, 'included');
      expect(dto.toJson()['complimentary'], isTrue);
    });

    test('point balance and withdrawal use Points not floats', () {
      final balance = PointBalanceDto.fromJson({
        'promotionalPoints': 1000,
        'earnedPoints': 500,
        'pendingWithdrawalPoints': 0,
      });
      expect(balance.toDomain().totalPoints, 1500);
      expect(balance.toDomain().earnedPoints, 500);
      expect(
        () => PointBalanceDto.fromJson({
          'promotionalPoints': 10.25,
          'earnedPoints': 0,
        }),
        throwsA(isA<JsonFormatException>()),
      );
      final withdrawal = WithdrawalRequestDto.fromJson({
        'id': 'w-1',
        'points': 500,
        'feePoints': 0,
        'netPoints': 500,
        'status': 'recorded',
        'createdAt': '2026-10-16T11:00:00.000Z',
      });
      expect(withdrawal.toDomain().status, WithdrawalStatus.recorded);
      expect(withdrawal.toDomain().points, 500);
    });

    test('live referral info keeps the invite link from JSON', () {
      final dto = ReferralInfoDto.fromJson({
        'code': 'K7M2NPQ4',
        'inviteLink': 'socialdating://invite/K7M2NPQ4',
        'shareMessage': 'Join me on Social Dating.',
        'isLive': true,
        'payoutsEnabled': false,
        'invitesSent': 2,
        'friendsJoined': 1,
        'pendingCommissionPaisa': 1000,
        'approvedCommissionPaisa': 0,
        'paidCommissionPaisa': 0,
        'reversedCommissionPaisa': 0,
      });
      final info = dto.toDomain();
      expect(info.isLive, isTrue);
      expect(info.payoutsEnabled, isFalse);
      expect(info.link, 'socialdating://invite/K7M2NPQ4');
      expect(info.shareText, 'Join me on Social Dating.');
      expect(info.pendingCommissionPaisa, 1000);
      expect(info.link, isNot(contains('https://')));
    });

    test('referral commission statuses round-trip', () {
      final commission = ReferralCommissionDto.fromJson({
        'id': 'c-1',
        'inviteId': 'inv-1',
        'personName': 'Bina',
        'amountPaisa': 1000,
        'status': 'pending',
        'createdAt': '2026-10-16T11:30:00.000Z',
      });
      expect(commission.toDomain().status, CommissionStatus.pending);
      expect(commission.toDomain().amountPaisa, 1000);
      expect(
        ReferralCommissionDto.fromJson({
          ...commission.toJson(),
          'status': 'reversed',
        }).toDomain().status,
        CommissionStatus.reversed,
      );
    });
  });

  group('notifications, reports and account settings', () {
    test('notification and report round-trip', () {
      final notification = NotificationDto.fromJson({
        'id': 'n-1',
        'type': 'match',
        'title': 'New match',
        'body': 'You and Asha liked each other.',
        'createdAt': '2026-10-16T12:00:00.000Z',
        'isRead': false,
      });
      expect(notification.toDomain().type, NotificationType.match);
      expect(
        () => NotificationDto.fromJson({
          'id': 'n-1',
          'type': 'match',
          'title': 'New match',
          'body': 'You and Asha liked each other.',
          'createdAt': '2026-10-16T12:00:00.000Z',
          'isRead': false,
          'phone': '+9779841234567',
        }),
        throwsA(isA<JsonFormatException>()),
      );
      final report = SafetyReportDto.fromJson({
        'id': 'r-1',
        'category': 'spam',
        'createdAt': '2026-10-16T12:05:00.000Z',
        'details': 'Repeated messages.',
        'subjectName': 'Asha',
      });
      expect(report.toDomain().category, 'spam');
    });

    test('account settings reject an E.164 phone field', () {
      expect(
        () => AccountSettingsDto.fromJson({
          'id': 'acc-1',
          'phone': '+9779841234567',
        }),
        throwsA(isA<JsonFormatException>()),
      );
      final settings = AccountSettingsDto.fromJson({
        'id': 'acc-1',
        'phoneLabel': '+977 ••••••4567',
        'showInDiscovery': false,
      });
      expect(settings.phoneLabel, contains('4567'));
      expect(settings.showInDiscovery, isFalse);
    });
  });

  group('pagination', () {
    test('page round-trips a cursor and items', () {
      final page = Page.fromJson({
        'items': [profileJson(), profileJson(id: 'p-2')],
        'nextCursor': 'cursor-2',
      }, ProfileDto.fromMap);
      expect(page.items, hasLength(2));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'cursor-2');
      final encoded = page.toJson((item) => item.toJson());
      expect((encoded['items'] as List), hasLength(2));
    });

    test('PageRequest clamps limit and omits an empty cursor', () {
      const request = PageRequest(limit: 500, cursor: '');
      expect(request.clampedLimit, PageRequest.maxLimit);
      expect(request.toQuery()['limit'], PageRequest.maxLimit);
      expect(request.toQuery().containsKey('cursor'), isFalse);
    });
  });

  group('history kinds', () {
    test('match history kind is a typed enum', () {
      final entry = MatchHistoryEntryDto.fromJson({
        'id': 'h-1',
        'profile': profileJson(),
        'kind': 'unmatched',
        'at': '2026-10-16T13:00:00.000Z',
      });
      expect(entry.toDomain().kind, MatchHistoryKind.unmatched);
    });
  });
}
