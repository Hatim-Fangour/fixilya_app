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
      developer.log('🔍 $message', name: tag ?? 'DEBUG');
    }
  }

  static void info(String message, [String? tag]) {
    if (_isDebugMode && _minLevel.index <= LogLevel.info.index) {
      developer.log('ℹ️ $message', name: tag ?? 'INFO');
    }
  }

  static void warning(String message, [String? tag]) {
    if (_isDebugMode && _minLevel.index <= LogLevel.warning.index) {
      developer.log('⚠️ $message', name: tag ?? 'WARNING');
    }
  }

  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    if (_isDebugMode && _minLevel.index <= LogLevel.error.index) {
      developer.log(
        '❌ $message',
        name: tag ?? 'ERROR',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
