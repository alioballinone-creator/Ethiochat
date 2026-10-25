sealed class Failure implements Exception {
  const Failure(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message';
}

final class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure([String message = 'The request timed out.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class ServerFailure extends Failure {
  const ServerFailure([String message = 'Something went wrong on our side.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class AuthFailure extends Failure {
  const AuthFailure([String message = 'Could not sign you in.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Please check your input.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class StorageFailure extends Failure {
  const StorageFailure([String message = 'Could not access local storage.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class PermissionFailure extends Failure {
  const PermissionFailure([String message = 'Permission denied.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Not found.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure([String message = 'Too many attempts. Please wait and try again.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'Unexpected error.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

Failure mapError(Object error, [StackTrace? stackTrace]) {
  if (error is Failure) return error;
  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('failed host lookup')) {
    return NetworkFailure('No internet connection.', null, error);
  }
  if (text.contains('timeout')) return TimeoutFailure('The request timed out.', null, error);
  if (text.contains('jwt') ||
      text.contains('token') ||
      text.contains('otp') ||
      text.contains('unauthorized')) {
    return AuthFailure('Could not sign you in.', null, error);
  }
  if (text.contains('rate limit') || text.contains('too many')) {
    return RateLimitFailure('Too many attempts. Please wait and try again.', null, error);
  }
  return UnknownFailure('Unexpected error.', null, error);
}
