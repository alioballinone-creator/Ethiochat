import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Thin wrapper over dart:developer so release builds stay quiet and no
/// personal data is ever logged.
abstract final class AppLogger {
  static void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.debug, message, error, stackTrace);

  static void info(String message) => _log(LogLevel.info, message, null, null);

  static void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.warning, message, error, stackTrace);

  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error, stackTrace);

  static void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (kReleaseMode && level == LogLevel.debug) return;
    developer.log(
      message,
      name: 'EthioChat.${level.name}',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}
