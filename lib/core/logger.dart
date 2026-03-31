import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 100,
      noBoxingByDefault: true,
    ),
  );

  static void debug(String module, String message) {
    _logger.d('[$module] $message');
  }

  static void info(String module, String message) {
    _logger.i('[$module] $message');
  }

  static void warning(String module, String message, {Object? error, StackTrace? stackTrace}) {
    _logger.w('[$module] $message', error: error, stackTrace: stackTrace);
  }

  static void error(String module, String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e('[$module] $message', error: error, stackTrace: stackTrace);
    // Send errors to Sentry
    Sentry.captureException(
      error ?? Exception('[$module] $message'),
      stackTrace: stackTrace,
    );
  }
}

// Module name constants
class LogModule {
  LogModule._();

  static const String api = 'API';
  static const String player = 'Player';
  static const String storage = 'Storage';
  static const String config = 'Config';
  static const String epg = 'EPG';
  static const String ui = 'UI';
}
