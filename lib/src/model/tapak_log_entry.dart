// ignore_for_file: deprecated_library_use
import 'dart:ui' show Color;

/// Severity level for a [TapakLogEntry].
enum TapakLogLevel {
  debug,
  info,
  success,
  warning,
  danger;

  String get label => switch (this) {
        debug => 'DEBUG',
        info => 'INFO',
        success => 'SUCCESS',
        warning => 'WARNING',
        danger => 'DANGER',
      };

  String get icon => switch (this) {
        debug => '◦',
        info => 'ℹ',
        success => '✓',
        warning => '⚠',
        danger => '✗',
      };

  /// ANSI escape code for console colour — kept for custom tooling.
  String get ansi => switch (this) {
        debug => '\x1B[90m', // grey
        info => '\x1B[36m', // cyan
        success => '\x1B[32m', // green
        warning => '\x1B[33m', // yellow
        danger => '\x1B[31m', // red
      };

  Color get color => switch (this) {
        debug => const Color(0xFF42A5F5), // blue
        info => const Color(0xFF26C6DA), // cyan
        success => const Color(0xFF66BB6A), // green
        warning => const Color(0xFFFFD600), // yellow
        danger => const Color(0xFFEF5350), // red
      };
}

/// A single custom log entry recorded via [TapakLog].
class TapakLogEntry {
  TapakLogEntry({
    required this.id,
    required this.title,
    required this.message,
    required this.level,
    required this.time,
  });

  final String id;

  /// Short tag that identifies the source, e.g. `remote_config`.
  final String title;

  /// The log message body.
  final String message;

  final TapakLogLevel level;
  final DateTime time;
}
