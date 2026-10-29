import 'dart:async';
import 'dart:io';

sealed class Failure implements Exception {
  const Failure(String message, {this.code, this.cause}) : _message = message;

  final String _message;
  final String? code;
  final Object? cause;

  String get message => cause == null ? _message : _englishMessage;

  String messageFor(String languageCode) {
    if (languageCode != 'am') {
      return cause == null ? _message : _englishMessage;
    }
    return switch (this) {
      NetworkFailure() =>
        'የበይነመረብ ግንኙነት የለም። ግንኙነቱን ያረጋግጡና እንደገና ይሞክሩ።',
      TimeoutFailure() => 'ጥያቄው ዘግይቷል። እባክዎ እንደገና ይሞክሩ።',
      AuthFailure() => 'መግባት አልተቻለም። መረጃዎን ያረጋግጡና እንደገና ይሞክሩ።',
      ValidationFailure() => 'ያስገቡትን መረጃ ያረጋግጡና እንደገና ይሞክሩ።',
      PermissionFailure() => 'ፈቃድ አልተሰጠም። ፈቃዱን ይፍቀዱና እንደገና ይሞክሩ።',
      NotFoundFailure() => 'የተጠየቀው ነገር አልተገኘም። እንደገና ይሞክሩ።',
      RateLimitFailure() => 'ብዙ ጊዜ ሞክረዋል። ትንሽ ቆይተው እንደገና ይሞክሩ።',
      StorageFailure() => 'መረጃውን ማስቀመጥ አልተቻለም። እንደገና ይሞክሩ።',
      ServerFailure() || UnknownFailure() =>
        'ችግር ተፈጥሯል። እባክዎ ቆይተው እንደገና ይሞክሩ።',
    };
  }

  String get _englishMessage => switch (this) {
        NetworkFailure() => 'No internet connection. Check your connection and try again.',
        TimeoutFailure() => 'The request timed out. Please try again.',
        AuthFailure() => 'Could not sign you in. Check your details and try again.',
        ValidationFailure() => 'Please check your information and try again.',
        PermissionFailure() => 'Permission was not granted. Allow it and try again.',
        NotFoundFailure() => 'The requested item was not found. Please try again.',
        RateLimitFailure() => 'Too many attempts. Please wait and try again.',
        StorageFailure() => 'Could not save your data. Please try again.',
        ServerFailure() || UnknownFailure() =>
          'Something went wrong. Please try again later.',
      };

  @override
  String toString() => 'Failure($code): $message';
}

final class NetworkFailure extends Failure {
  const NetworkFailure(
      [String message = 'No internet connection.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure(
      [String message = 'The request timed out.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class ServerFailure extends Failure {
  const ServerFailure(
      [String message = 'Something went wrong on our side.',
      String? code,
      Object? cause])
      : super(message, code: code, cause: cause);
}

final class AuthFailure extends Failure {
  const AuthFailure(
      [String message = 'Could not sign you in.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(
      [String message = 'Please check your input.',
      String? code,
      Object? cause])
      : super(message, code: code, cause: cause);
}

final class StorageFailure extends Failure {
  const StorageFailure(
      [String message = 'Could not access local storage.',
      String? code,
      Object? cause])
      : super(message, code: code, cause: cause);
}

final class PermissionFailure extends Failure {
  const PermissionFailure(
      [String message = 'Permission denied.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(
      [String message = 'Not found.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure(
      [String message = 'Too many attempts. Please wait and try again.',
      String? code,
      Object? cause])
      : super(message, code: code, cause: cause);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(
      [String message = 'Unexpected error.', String? code, Object? cause])
      : super(message, code: code, cause: cause);
}

Failure mapError(Object error, [StackTrace? stackTrace]) {
  if (error is Failure) return error;
  if (error is TimeoutException) {
    return TimeoutFailure('The request timed out.', 'timeout', error);
  }
  if (error is SocketException || error is HttpException) {
    return NetworkFailure('No internet connection.', 'network', error);
  }
  if (error is FormatException) {
    return ValidationFailure('Please check your input.', 'validation', error);
  }
  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('failed host lookup')) {
    return NetworkFailure('No internet connection.', 'network', error);
  }
  if (text.contains('timeout')) {
    return TimeoutFailure('The request timed out.', 'timeout', error);
  }
  if (text.contains('404') || text.contains('not found')) {
    return NotFoundFailure('The requested item was not found.', 'not_found', error);
  }
  if (text.contains('500') ||
      text.contains('502') ||
      text.contains('503') ||
      text.contains('server')) {
    return ServerFailure('Something went wrong on our side.', 'server', error);
  }
  if (text.contains('jwt') ||
      text.contains('token') ||
      text.contains('otp') ||
      text.contains('unauthorized')) {
    return AuthFailure('Could not sign you in.', 'auth', error);
  }
  if (text.contains('rate limit') || text.contains('too many')) {
    return RateLimitFailure(
      'Too many attempts. Please wait and try again.',
      'rate_limit',
      error,
    );
  }
  if (text.contains('permission denied') || text.contains('permission')) {
    return PermissionFailure('Permission denied.', 'permission', error);
  }
  if (text.contains('sqlite') || text.contains('database') || text.contains('storage')) {
    return StorageFailure('Could not access local storage.', 'storage', error);
  }
  return UnknownFailure('Something went wrong. Please try again.', 'unknown', error);
}
