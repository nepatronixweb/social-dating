import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/data/api/auth_paths.dart';
import 'package:social_dating/data/repositories/api_auth_repository.dart';
import 'package:social_dating/data/services/api_client.dart';
import 'package:social_dating/data/services/token_storage.dart';

void main() {
  late MemoryTokenStorage tokens;
  late _ScriptedAdapter adapter;
  late ApiAuthRepository repo;

  setUp(() {
    tokens = MemoryTokenStorage();
    adapter = _ScriptedAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://auth.test'))
      ..httpClientAdapter = adapter;
    repo = ApiAuthRepository(
      client: ApiClient(dio: dio, isNetworkEnabled: () => true, tokens: tokens),
      tokens: tokens,
    );
  });

  Map<String, Object?> accountJson({
    String id = 'acc-1',
    bool termsAccepted = false,
    bool? isAgeEligible,
    String? displayName,
  }) => {
    'id': id,
    'termsAccepted': termsAccepted,
    'isAgeEligible': isAgeEligible,
    'displayName': displayName,
  };

  Map<String, Object?> sessionJson({
    String access = 'access-1',
    String refresh = 'refresh-1',
  }) => {
    'account': accountJson(),
    'accessToken': access,
    'refreshToken': refresh,
    'expiresAt': '2026-10-29T12:00:00.000Z',
  };

  test('requestCode posts the confirmed path and phone field', () async {
    adapter.queue(AuthApiPaths.requestCode, (options) {
      expect(options.method, 'POST');
      expect(options.data, {'phone': '+9779841234567'});
      expect(options.headers['Authorization'], isNull);
      return _json(200, {'retryAfterSeconds': 30});
    });

    final registered = await repo.requestCode('+9779841234567');
    expect(registered, isFalse);
    expect(adapter.remaining, 0);
  });

  test('requestCode reports a registered number', () async {
    adapter.queue(AuthApiPaths.requestCode, (_) {
      return _json(200, {'retryAfterSeconds': 30, 'registered': true});
    });

    expect(await repo.requestCode('+9779841234567'), isTrue);
  });

  test(
    'verify stores tokens and never treats 123456 as a magic code',
    () async {
      adapter.queue(AuthApiPaths.verify, (options) {
        expect(options.data, {
          'phone': '+9779841234567',
          'code': '123456',
        });
        return _json(401, {
          'title': 'That code isn\'t right.',
          'detail': 'Check the code and try again.',
        });
      });

      await expectLater(
        repo.verifyCode(phone: '+9779841234567', code: '123456'),
        throwsA(isA<InvalidCodeFailure>()),
      );
      expect(await tokens.readAccessToken(), isNull);
    },
  );

  test('expired verify 401 becomes CodeExpiredFailure', () async {
    adapter.queue(AuthApiPaths.verify, (_) {
      return _json(401, {
        'title': 'That code isn\'t right.',
        'detail': 'Request a new code and try again.',
      });
    });

    await expectLater(
      repo.verifyCode(phone: '+9779841234567', code: '000000'),
      throwsA(isA<CodeExpiredFailure>()),
    );
  });

  test('successful verify persists tokens and hides the phone', () async {
    adapter.queue(AuthApiPaths.verify, (_) => _json(200, sessionJson()));

    final account = await repo.verifyCode(
      phone: '+9779841234567',
      code: '482913',
    );
    expect(account.id, 'acc-1');
    expect(account.termsAccepted, isFalse);
    expect(await tokens.readAccessToken(), 'access-1');
    expect(await tokens.readRefreshToken(), 'refresh-1');
  });

  test('login verify tells the API to skip first-time setup', () async {
    adapter.queue(AuthApiPaths.verify, (options) {
      expect(options.data, {
        'phone': '+9779841234567',
        'code': '123456',
        'login': true,
      });
      return _json(200, {
        'account': accountJson(
          termsAccepted: true,
          isAgeEligible: true,
          displayName: 'You',
        ),
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'expiresAt': '2026-10-29T12:00:00.000Z',
      });
    });

    final account = await repo.verifyCode(
      phone: '+9779841234567',
      code: '123456',
      login: true,
    );
    expect(account.termsAccepted, isTrue);
    expect(account.displayName, 'You');
  });

  test('account JSON that includes a phone is rejected', () async {
    adapter.queue(AuthApiPaths.verify, (_) {
      return _json(200, {
        ...sessionJson(),
        'account': {'id': 'acc-1', 'phone': '+9779841234567'},
      });
    });

    await expectLater(
      repo.verifyCode(phone: '+9779841234567', code: '482913'),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('authenticated calls send the bearer token', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(AuthApiPaths.terms, (options) {
      expect(options.headers['Authorization'], 'Bearer access-1');
      return _json(200, accountJson(termsAccepted: true));
    });

    final account = await repo.acceptTerms('acc-1');
    expect(account.termsAccepted, isTrue);
  });

  test('setGender posts the wire name', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(AuthApiPaths.gender, (options) {
      expect(options.method, 'POST');
      expect(options.data, {'gender': 'female'});
      expect(options.headers['Authorization'], 'Bearer access-1');
      return _json(200, {
        'id': 'acc-1',
        'termsAccepted': true,
        'isAgeEligible': true,
        'gender': 'female',
      });
    });

    final saved = await repo.setGender('acc-1', 'female');
    expect(saved.gender, 'female');
  });

  test('401 on an authed call refreshes once then retries', () async {
    await tokens.writeSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );
    adapter.queue(AuthApiPaths.profile, (options) {
      if (options.headers['Authorization'] == 'Bearer old-access') {
        return _json(401, {
          'title': 'Please sign in again.',
          'detail': 'The session is no longer valid.',
        });
      }
      expect(options.headers['Authorization'], 'Bearer access-2');
      expect(options.data, {
        'displayName': 'Ada',
        'bio': '',
        'interests': <String>[],
      });
      return _json(200, accountJson(termsAccepted: true, displayName: 'Ada'));
    }, times: 2);
    adapter.queue(AuthApiPaths.refresh, (options) {
      expect(options.data, {'refreshToken': 'old-refresh'});
      return _json(200, sessionJson(access: 'access-2', refresh: 'refresh-2'));
    });

    final account = await repo.completeProfile('acc-1', 'Ada');
    expect(account.displayName, 'Ada');
    expect(await tokens.readAccessToken(), 'access-2');
    expect(await tokens.readRefreshToken(), 'refresh-2');
  });

  test('completeProfile posts bio and interests', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(AuthApiPaths.profile, (options) {
      expect(options.data, {
        'displayName': 'Ada',
        'bio': 'Hikes on Saturday.',
        'interests': ['Hiking', 'Coffee', 'Film'],
        'city': 'Kathmandu',
        'gender': 'female',
      });
      return _json(200, accountJson(termsAccepted: true, displayName: 'Ada'));
    });

    final saved = await repo.completeProfile(
      'acc-1',
      'Ada',
      bio: 'Hikes on Saturday.',
      interests: const ['Hiking', 'Coffee', 'Film'],
      city: 'Kathmandu',
      gender: 'female',
    );
    expect(saved.displayName, 'Ada');
  });

  test('submitBirthDate sends a calendar date only', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(AuthApiPaths.age, (options) {
      expect(options.data, {'birthDate': '2000-01-15'});
      return _json(200, accountJson(termsAccepted: true, isAgeEligible: true));
    });

    final account = await repo.submitBirthDate('acc-1', DateTime(2000, 1, 15));
    expect(account.isAgeEligible, isTrue);
  });

  test('signOut revokes then clears only if tokens did not rotate', () async {
    await tokens.writeSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
    adapter.queue(AuthApiPaths.signOut, (options) {
      expect(options.headers['Authorization'], 'Bearer access-1');
      expect(options.data, {'refreshToken': 'refresh-1'});
      return _empty(204);
    });

    await repo.signOut();
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
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
