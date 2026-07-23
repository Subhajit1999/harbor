import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Central logging — tagged by subsystem so `flutter run` output (or a
/// device console) actually shows *which* resolver ran, what it found,
/// and why something failed, instead of the app silently doing the wrong
/// thing with no trace (exactly how the "app says photo post, curl says
/// it's fine" bug went undiagnosed as long as it did — nothing logged
/// which resolver got picked or what it saw).
///
/// Stripped to a no-op in release builds — this is a debugging aid, not
/// user-facing telemetry (Harbor doesn't collect analytics; see Settings ->
/// Privacy), so there's nothing worth the overhead once the app is what a
/// real user is running.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 6,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kReleaseMode ? Level.off : Level.debug,
  );

  static void d(String tag, String message) => _logger.d('[$tag] $message');
  static void i(String tag, String message) => _logger.i('[$tag] $message');
  static void w(String tag, String message) => _logger.w('[$tag] $message');

  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e('[$tag] $message', error: error, stackTrace: stackTrace);
}
