import 'api_error_mapper.dart';

/// Domain-level failures surfaced to the UI. Messages are user-safe: they
/// never include stack traces, URLs, or server internals.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Short, human-readable text safe to show in the UI.
  final String message;

  String get title => 'Something went wrong';

  @override
  String toString() => '$runtimeType($message)';

  /// Maps any thrown object to an [AppFailure].
  static AppFailure from(Object error) => ApiErrorMapper.map(error);
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Check your connection and try again.',
  ]);
  @override
  String get title => 'You\'re offline';
}

class ServerFailure extends AppFailure {
  const ServerFailure([
    super.message = 'Our servers are having a moment. Please try again soon.',
  ]);
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.message = 'Please sign in again.']);
  @override
  String get title => 'Session expired';
}

/// Authenticated, but not allowed to perform this action.
class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([super.message = 'You do not have access to that.']);
  @override
  String get title => 'Not allowed';
}

/// Too many attempts. [retryAfter] is informational when the server sent it.
class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure([
    super.message = 'Too many attempts. Wait a moment and try again.',
    this.retryAfter,
  ]);

  final Duration? retryAfter;

  @override
  String get title => 'Slow down';
}

/// The in-flight request was cancelled (navigation, a newer page load).
class RequestCancelledFailure extends AppFailure {
  const RequestCancelledFailure([
    super.message = 'That request was cancelled.',
  ]);
}

/// The backend has not confirmed an endpoint contract. API repositories throw
/// this instead of inventing a path or recording a fake financial success.
class ApiContractMissingFailure extends AppFailure {
  const ApiContractMissingFailure(this.operation)
    : super(
        'This feature is not connected. The backend has not confirmed '
        'an API contract for $operation.',
      );

  final String operation;

  @override
  String get title => 'Not connected yet';
}

/// Thrown when code attempts a network call while the app is in the
/// frontend-only phase.
class NetworkDisabledFailure extends AppFailure {
  const NetworkDisabledFailure([
    super.message = 'Networking is disabled in this build.',
  ]);
  @override
  String get title => 'Not connected yet';
}

/// The thing asked for no longer exists (for example a closed conversation).
class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'That is no longer available.']);
  @override
  String get title => 'No longer available';
}

/// Input or mock-credential problems the user can fix (e.g. a wrong code).
class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
  @override
  String get title => 'Check your details';
}

/// The entered one-time code was wrong.
class InvalidCodeFailure extends ValidationFailure {
  const InvalidCodeFailure([
    super.message = 'That code isn\'t right. Check it and try again.',
  ]);
  @override
  String get title => 'Incorrect code';
}

/// The one-time code is no longer valid; a new one must be requested.
class CodeExpiredFailure extends AppFailure {
  const CodeExpiredFailure([
    super.message = 'That code has expired. Request a new one.',
  ]);
  @override
  String get title => 'Code expired';
}

/// Sign-in or account setup was rejected for a reason the user can't fix by
/// editing their input (the generic authentication failure state).
class AuthenticationFailure extends AppFailure {
  const AuthenticationFailure([
    super.message = 'We couldn\'t sign you in. Please try again.',
  ]);
  @override
  String get title => 'Sign-in failed';
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([
    super.message = 'An unexpected error occurred. Please try again.',
  ]);
}
