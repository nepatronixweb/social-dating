import 'package:dio/dio.dart';

import 'app_failure.dart';

/// Maps transport and HTTP failures to user-safe [AppFailure] values.
///
/// Status codes follow typical ASP.NET Core / RFC 9110 usage. Response bodies
/// are treated as optional RFC 7807 Problem Details; unknown shapes never leak
/// URLs, stack traces or server internals into [AppFailure.message].
abstract final class ApiErrorMapper {
  static AppFailure map(Object error) {
    if (error is AppFailure) return error;
    if (error is JsonFormatException) {
      return ValidationFailure(error.message);
    }
    if (error is DioException) return _fromDio(error);
    return const UnknownFailure();
  }

  static AppFailure _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        return _fromStatus(
          error.response?.statusCode ?? 0,
          error.response?.data,
          error.response?.headers,
        );
      case DioExceptionType.cancel:
        if (error.error is AppFailure) return error.error! as AppFailure;
        return const RequestCancelledFailure();
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return const UnknownFailure();
    }
  }

  static AppFailure _fromStatus(int code, Object? body, Headers? headers) {
    switch (code) {
      case 400:
      case 422:
        return ValidationFailure(
          _problemMessage(body) ?? 'Check your details.',
        );
      case 401:
        return UnauthorizedFailure(
          _problemMessage(body) ?? 'Please sign in again.',
        );
      case 403:
        return ForbiddenFailure(
          _problemMessage(body) ?? 'You do not have access to that.',
        );
      case 404:
        return NotFoundFailure(
          _problemMessage(body) ?? 'That is no longer available.',
        );
      case 429:
        return RateLimitedFailure(
          _problemMessage(body) ??
              'Too many attempts. Wait a moment and try again.',
          _retryAfter(headers),
        );
      default:
        if (code >= 500 && code <= 599) {
          return const ServerFailure();
        }
        return const ServerFailure();
    }
  }

  static String? _problemMessage(Object? body) {
    if (body is! Map) return null;
    final title = body['title'];
    final detail = body['detail'];
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty && first.first is String) {
        return first.first as String;
      }
      if (first is String && first.isNotEmpty) return first;
    }
    if (detail is String && detail.isNotEmpty && _isSafeClientMessage(detail)) {
      return detail;
    }
    if (title is String && title.isNotEmpty && _isSafeClientMessage(title)) {
      return title;
    }
    return null;
  }

  /// Rejects messages that look like traces, URLs or raw exception dumps.
  static bool _isSafeClientMessage(String value) {
    if (value.length > 180) return false;
    final lower = value.toLowerCase();
    if (lower.contains('http:') || lower.contains('https:')) return false;
    if (lower.contains('exception') || lower.contains('stack')) return false;
    if (value.contains('\n')) return false;
    return true;
  }

  static Duration? _retryAfter(Headers? headers) {
    if (headers == null) return null;
    final raw = headers.value('retry-after');
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }
}

/// Thrown when a DTO cannot be read. Mapped to [ValidationFailure] at the
/// repository boundary; tests may catch it directly.
class JsonFormatException implements Exception {
  const JsonFormatException(this.message);

  final String message;

  @override
  String toString() => 'JsonFormatException($message)';
}
