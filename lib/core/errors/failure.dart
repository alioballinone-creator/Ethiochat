/// Typed failures. No raw exception may cross from data/domain into the UI.
sealed class Failure implements Exception {
  const Failure(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message';
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection.',
    super.code,
    super.cause,
  ]);
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out.']);
}

final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Something went wrong on our side.',
    super.code,
    super.cause,
  ]);
}

final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Could not sign you in.', super.code]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Please check your input.']);
}

final class StorageFailure extends Failure {
  const StorageFailure([
    super.message = 'Could not access local storage.',
    super.code,
    super.cause,
  ]);
}

final class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission denied.']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found.']);
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure([
    super.message = 'Too many attempts. Please wait and try again.',
  ]);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unexpected error.', super.code,
      super.cause,]);
}

/// Maps an arbitrary object (usually from Supabase) to a [Failure].
Failure mapError(Object error, [StackTrace? _]) {
  if (error is Failure) return error;
  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('failed host lookup')) {
    return NetworkFailure(cause: error);
  }
  if (text.contains('timeout')) return TimeoutFailure();
  if (text.contains('jwt') ||
      text.contains('token') ||
      text.contains('otp') ||
      text.contains('unauthorized')) {
    return AuthFailure(cause: error);
  }
  if (text.contains('rate limit') || text.contains('too many')) {
    return RateLimitFailure();
  }
  return UnknownFailure(cause: error);
}
