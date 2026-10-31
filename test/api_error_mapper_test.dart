import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/errors/api_error_mapper.dart';
import 'package:social_dating/core/errors/app_failure.dart';

void main() {
  DioException dio(
    DioExceptionType type, {
    int? status,
    Object? data,
    Map<String, List<String>>? headers,
  }) {
    return DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: status,
              data: data,
              headers: Headers.fromMap(headers ?? const {}),
            ),
    );
  }

  group('ApiErrorMapper', () {
    test('maps network timeouts', () {
      expect(
        ApiErrorMapper.map(dio(DioExceptionType.connectionTimeout)),
        isA<NetworkFailure>(),
      );
    });

    test('maps 400 problem details to validation', () {
      final failure = ApiErrorMapper.map(
        dio(
          DioExceptionType.badResponse,
          status: 400,
          data: {
            'title': 'One or more validation errors occurred.',
            'errors': {
              'phone': ['Enter a valid number.'],
            },
          },
        ),
      );
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Enter a valid number.');
    });

    test('maps 401 and 403 separately', () {
      expect(
        ApiErrorMapper.map(dio(DioExceptionType.badResponse, status: 401)),
        isA<UnauthorizedFailure>(),
      );
      expect(
        ApiErrorMapper.map(dio(DioExceptionType.badResponse, status: 403)),
        isA<ForbiddenFailure>(),
      );
    });

    test('maps 404, 429 and 500', () {
      expect(
        ApiErrorMapper.map(dio(DioExceptionType.badResponse, status: 404)),
        isA<NotFoundFailure>(),
      );
      final limited = ApiErrorMapper.map(
        dio(
          DioExceptionType.badResponse,
          status: 429,
          headers: {
            'retry-after': ['30'],
          },
        ),
      );
      expect(limited, isA<RateLimitedFailure>());
      expect(
        (limited as RateLimitedFailure).retryAfter,
        const Duration(seconds: 30),
      );
      expect(
        ApiErrorMapper.map(dio(DioExceptionType.badResponse, status: 500)),
        isA<ServerFailure>(),
      );
    });

    test('drops unsafe problem-detail text', () {
      final failure = ApiErrorMapper.map(
        dio(
          DioExceptionType.badResponse,
          status: 500,
          data: {'detail': 'NullReferenceException at UserService.cs:88'},
        ),
      );
      expect(failure, isA<ServerFailure>());
      expect(failure.message, isNot(contains('UserService')));
    });

    test('cancel without a nested failure is RequestCancelledFailure', () {
      expect(
        ApiErrorMapper.map(dio(DioExceptionType.cancel)),
        isA<RequestCancelledFailure>(),
      );
    });

    test('JsonFormatException becomes ValidationFailure', () {
      expect(
        AppFailure.from(
          const JsonFormatException('Expected an integer at \$.pricePaisa.'),
        ),
        isA<ValidationFailure>(),
      );
    });
  });
}
