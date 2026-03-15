import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class Logger {
  Logger._();

  static bool _isDebugMode = true;
  static LogLevel _minLevel = LogLevel.debug;

  static void init({
    bool debugMode = true,
    LogLevel minLevel = LogLevel.debug,
  }) {
    _isDebugMode = debugMode;
    _minLevel = minLevel;
  }

  static void debug(String message, [String? tag]) {
    if (_isDebugMode && _minLevel.index <= LogLevel.debug.index) {
      developer.log('DEBUG: $message', name: tag ?? 'DEBUG');
    }
  }

  static void info(String message, [String? tag]) {
    if (_isDebugMode && _minLevel.index <= LogLevel.info.index) {
      developer.log('INFO: $message', name: tag ?? 'INFO');
    }
  }

  /// Warnings are always logged regardless of debug mode, because they
  /// indicate potential problems that should be investigated.
  static void warning(String message, [String? tag]) {
    developer.log('WARNING: $message', name: tag ?? 'WARNING');
  }

  /// Errors are always logged regardless of debug mode, because silent
  /// failures in production make debugging impossible.
  /// TODO: Integrate Crashlytics or Sentry here for production error reporting.
  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    developer.log(
      'ERROR: $message',
      name: tag ?? 'ERROR',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
