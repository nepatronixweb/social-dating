import 'package:dio/dio.dart';

import '../../core/config/integration_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/app_logger.dart';
import '../api/auth_paths.dart';
import 'token_storage.dart';

/// Networking configuration for the API integration layer.
///
/// Hosts come from `--dart-define=API_BASE_URL`. No environment URL is
/// compiled in. Sockets stay closed until [IntegrationConfig.networkEnabled]
/// is true (API data source, a host, and `API_NETWORK=true`).
abstract final class ApiConfig {
  static bool get networkEnabled => IntegrationConfig.networkEnabled;

  static String get baseUrl => IntegrationConfig.apiBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Origin only. A trailing slash would make Dio drop the first path segment.
  static String normalizedBaseUrl(String origin) {
    if (origin.isEmpty) return origin;
    if (origin.endsWith('/')) {
      return origin.substring(0, origin.length - 1);
    }
    return origin;
  }
}

/// Rejects every request while networking is disabled.
class NetworkGuardInterceptor extends Interceptor {
  NetworkGuardInterceptor({required this.isEnabled});

  final bool Function() isEnabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (isEnabled()) {
      handler.next(options);
      return;
    }
    AppLogger.debug('Blocked request (networking disabled): ${options.path}');
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: const NetworkDisabledFailure(),
      ),
    );
  }
}

/// Attaches the access token on confirmed, authenticated paths.
class AuthHeaderInterceptor extends Interceptor {
  AuthHeaderInterceptor(this._tokens);

  final TokenStorage _tokens;

  static const skipHeaderExtra = 'skipAuthHeader';

  static const _publicPaths = {
    AuthApiPaths.requestCode,
    AuthApiPaths.verify,
    AuthApiPaths.refresh,
  };

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (options.extra[skipHeaderExtra] == true ||
          _isPublic(options.uri.path)) {
        handler.next(options);
        return;
      }
      final access = await _tokens.readAccessToken();
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
      handler.next(options);
    } catch (error, stack) {
      handler.reject(
        DioException(requestOptions: options, error: error, stackTrace: stack),
      );
    }
  }

  static bool _isPublic(String path) {
    final normalized = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return _publicPaths.contains(normalized);
  }
}

/// Thin wrapper around [Dio]. Constructed lazily by a provider; constructing it
/// performs no I/O.
class ApiClient {
  ApiClient({Dio? dio, bool Function()? isNetworkEnabled, TokenStorage? tokens})
    : dio = _configure(
        dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.normalizedBaseUrl(ApiConfig.baseUrl),
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                headers: const {'Accept': 'application/json'},
              ),
            ),
        isNetworkEnabled ?? () => ApiConfig.networkEnabled,
        tokens,
      );

  final Dio dio;

  static Dio _configure(
    Dio dio,
    bool Function() isEnabled,
    TokenStorage? tokens,
  ) {
    dio.interceptors.add(NetworkGuardInterceptor(isEnabled: isEnabled));
    if (tokens != null) {
      dio.interceptors.add(AuthHeaderInterceptor(tokens));
    }
    return dio;
  }
}
