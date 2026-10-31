import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/data/services/api_client.dart';
import 'package:social_dating/data/services/service_providers.dart';
import 'package:social_dating/features/discovery/providers/mock_discovery_providers.dart';
import 'package:social_dating/features/settings/providers/theme_mode_provider.dart';

void main() {
  group('networking is disabled in Phase 0', () {
    test('ApiConfig.networkEnabled is false', () {
      expect(ApiConfig.networkEnabled, isFalse);
    });

    test(
      'default client rejects requests without touching the network',
      () async {
        final client = ApiClient();
        await expectLater(
          client.dio.get<dynamic>('/anything'),
          throwsA(
            isA<DioException>().having(
              (e) => AppFailure.from(e),
              'failure',
              isA<NetworkDisabledFailure>(),
            ),
          ),
        );
      },
    );

    test('guard forwards requests when explicitly enabled', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost.invalid'))
        ..interceptors.add(NetworkGuardInterceptor(isEnabled: () => true))
        ..httpClientAdapter = _StubAdapter();
      final response = await dio.get<String>('/ok');
      expect(response.data, 'stub');
    });

    test('creating providers performs no I/O', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(() => container.read(apiClientProvider), returnsNormally);
    });
  });

  group('theme mode persistence', () {
    test('defaults to system and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('pref.theme_mode'), 'dark');
    });

    test('restores stored mode and ignores garbage', () async {
      SharedPreferences.setMockInitialValues({'pref.theme_mode': 'light'});
      var prefs = await SharedPreferences.getInstance();
      var container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(container.read(themeModeProvider), ThemeMode.light);
      container.dispose();

      SharedPreferences.setMockInitialValues({'pref.theme_mode': 'nonsense'});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });

  group('mock repository', () {
    test('populated, empty and failure scenarios', () async {
      const zero = Duration.zero;
      expect(
        await const MockProfileRepository(
          latency: zero,
        ).fetchSuggestedProfiles(),
        isNotEmpty,
      );
      expect(
        await const MockProfileRepository(
          scenario: MockScenario.empty,
          latency: zero,
        ).fetchSuggestedProfiles(),
        isEmpty,
      );
      await expectLater(
        const MockProfileRepository(
          scenario: MockScenario.failure,
          latency: zero,
        ).fetchSuggestedProfiles(),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('all mock ids are visibly prefixed', () {
      expect(mockProfiles.every((p) => p.id.startsWith('mock-')), isTrue);
    });

    test('provider surfaces failure as AsyncError without retrying', () async {
      final container = ProviderContainer(
        overrides: [
          mockProfileRepositoryProvider.overrideWith(
            (ref) => const MockProfileRepository(
              scenario: MockScenario.failure,
              latency: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(mockSuggestedProfilesProvider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(
        container.read(mockSuggestedProfilesProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(container.read(mockSuggestedProfilesProvider).hasError, isTrue);
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('stub', 200);
}
