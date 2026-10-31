import 'package:flutter/foundation.dart';

/// Which data source the repository providers should construct.
///
/// Chosen only from `--dart-define=DATA_SOURCE=mock|api`. Debug builds default
/// to [mock]. Release builds default to [api] so a production binary cannot
/// silently record fake payments, wallet credits or referral commissions.
enum DataSource { mock, api }

/// Named environment for the (future) API host.
///
/// The host itself is never compiled in. Supply it with
/// `--dart-define=API_BASE_URL=...` per environment. No secrets belong here.
enum AppFlavor { development, staging, production }

/// Build-time integration switches. All values come from `--dart-define`.
///
/// | Define | Meaning |
/// | --- | --- |
/// | `APP_ENV` | `development` (default), `staging`, or `production` |
/// | `API_BASE_URL` | Origin only, no path. Empty until a host is supplied. |
/// | `DATA_SOURCE` | `mock` or `api`. Unset: mock in debug, api in release. |
/// | `ALLOW_MOCK_DATA` | Required to use `DATA_SOURCE=mock` in a release binary. |
/// | `API_NETWORK` | Must be `true` before Dio is allowed to leave the device. |
abstract final class IntegrationConfig {
  static const String dataSourceDefine = String.fromEnvironment('DATA_SOURCE');

  static const String flavorDefine = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Origin for the future ASP.NET Core API. Never a secret; never a fallback
  /// production host.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const bool allowMockData = bool.fromEnvironment(
    'ALLOW_MOCK_DATA',
    defaultValue: false,
  );

  /// Socket permission. Stays false until a host is supplied. The default is
  /// always false. Auth `/v1` is confirmed; other API repositories still
  /// refuse unconfirmed operations.
  static const bool apiNetwork = bool.fromEnvironment(
    'API_NETWORK',
    defaultValue: false,
  );

  static AppFlavor get flavor => parseFlavor(flavorDefine);

  static DataSource get dataSource => resolveDataSource(
    declared: dataSourceDefine,
    isRelease: kReleaseMode,
    allowMockInRelease: allowMockData,
  );

  static bool get useMockRepositories => dataSource == DataSource.mock;

  /// True only when every gate required to open a socket is set. Unconfirmed
  /// feature repositories still refuse rather than inventing paths.
  static bool get networkEnabled =>
      dataSource == DataSource.api && apiBaseUrl.isNotEmpty && apiNetwork;

  /// Call once at startup so a misconfigured release binary fails loudly
  /// before any repository can record a fake financial success.
  static void assertSafeDataSource() {
    dataSource;
    parseFlavor(flavorDefine);
  }
}

/// Parses `APP_ENV`. Unknown values fail loudly; they are never mapped to
/// production.
AppFlavor parseFlavor(String raw) {
  switch (raw.trim().toLowerCase()) {
    case '':
    case 'development':
    case 'dev':
      return AppFlavor.development;
    case 'staging':
      return AppFlavor.staging;
    case 'production':
    case 'prod':
      return AppFlavor.production;
    default:
      throw StateError(
        'APP_ENV must be development, staging or production (got "$raw").',
      );
  }
}

/// Resolves the data source from dart-defines and the build mode.
///
/// Release binaries never default to mock. `DATA_SOURCE=mock` in release
/// requires [allowMockInRelease] so the choice cannot be accidental.
DataSource resolveDataSource({
  required String declared,
  required bool isRelease,
  required bool allowMockInRelease,
}) {
  final value = declared.trim().toLowerCase();
  switch (value) {
    case 'api':
      return DataSource.api;
    case 'mock':
      if (isRelease && !allowMockInRelease) {
        throw StateError(
          'Release builds cannot use DATA_SOURCE=mock unless '
          'ALLOW_MOCK_DATA=true. Silent mock financial success is forbidden.',
        );
      }
      return DataSource.mock;
    case '':
      return isRelease ? DataSource.api : DataSource.mock;
    default:
      throw StateError('DATA_SOURCE must be mock or api (got "$declared").');
  }
}
