import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/config/integration_config.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/data/repositories/api_repositories.dart';
import 'package:social_dating/data/services/api_client.dart';
import 'package:social_dating/data/services/token_storage.dart';

void main() {
  group('IntegrationConfig (this debug build)', () {
    test('defaults to mock repositories and a closed network', () {
      expect(IntegrationConfig.useMockRepositories, isTrue);
      expect(IntegrationConfig.dataSource, DataSource.mock);
      expect(IntegrationConfig.flavor, AppFlavor.development);
      expect(ApiConfig.networkEnabled, isFalse);
      expect(ApiConfig.baseUrl, isEmpty);
    });
  });

  group('resolveDataSource', () {
    test('debug with an unset define uses mock', () {
      expect(
        resolveDataSource(
          declared: '',
          isRelease: false,
          allowMockInRelease: false,
        ),
        DataSource.mock,
      );
    });

    test('release with an unset define uses api, not mock', () {
      expect(
        resolveDataSource(
          declared: '',
          isRelease: true,
          allowMockInRelease: false,
        ),
        DataSource.api,
      );
    });

    test('explicit api is always api', () {
      expect(
        resolveDataSource(
          declared: 'api',
          isRelease: false,
          allowMockInRelease: false,
        ),
        DataSource.api,
      );
    });

    test('release refuses accidental mock without ALLOW_MOCK_DATA', () {
      expect(
        () => resolveDataSource(
          declared: 'mock',
          isRelease: true,
          allowMockInRelease: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('release may use mock only when explicitly allowed', () {
      expect(
        resolveDataSource(
          declared: 'mock',
          isRelease: true,
          allowMockInRelease: true,
        ),
        DataSource.mock,
      );
    });

    test('unknown DATA_SOURCE fails loudly', () {
      expect(
        () => resolveDataSource(
          declared: 'live',
          isRelease: false,
          allowMockInRelease: false,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('parseFlavor', () {
    test('accepts development, staging and production', () {
      expect(parseFlavor('development'), AppFlavor.development);
      expect(parseFlavor('staging'), AppFlavor.staging);
      expect(parseFlavor('production'), AppFlavor.production);
    });

    test('rejects unknown flavors', () {
      expect(() => parseFlavor('qa'), throwsA(isA<StateError>()));
    });
  });

  group('API repositories refuse unconfirmed contracts', () {
    test('wallet submit never records a fake payout', () async {
      await expectLater(
        ApiWalletRepository(
          client: ApiClient(
            dio: Dio(),
            isNetworkEnabled: () => false,
            tokens: MemoryTokenStorage(),
          ),
          tokens: MemoryTokenStorage(),
        ).submitWithdrawal(points: 500, confirmed: false),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('subscription checkout never returns a succeeded payment', () async {
      final repo = ApiSubscriptionRepository(
        client: ApiClient(
          dio: Dio(),
          isNetworkEnabled: () => false,
          tokens: MemoryTokenStorage(),
        ),
        tokens: MemoryTokenStorage(),
      );
      await expectLater(
        repo.submitCheckout(
          planId: 'npr-100',
          referralLinked: true,
          methodId: 'card',
          confirmed: false,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        repo.submitCheckout(
          planId: 'npr-100',
          referralLinked: true,
          methodId: 'card',
          confirmed: true,
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('referral confirm never marks a commission paid', () async {
      await expectLater(
        ApiReferralRepository(
          client: ApiClient(
            dio: Dio(),
            isNetworkEnabled: () => false,
            tokens: MemoryTokenStorage(),
          ),
          tokens: MemoryTokenStorage(),
        ).confirmQualifyingPurchase('invite-1'),
        throwsA(
          isA<ApiContractMissingFailure>().having(
            (e) => e.operation,
            'operation',
            'referrals.confirmPurchase',
          ),
        ),
      );
    });
  });
}
