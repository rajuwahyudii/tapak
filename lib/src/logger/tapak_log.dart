import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/tapak_log_entry.dart';
import '../store/tapak_store.dart';

/// Custom debug logger for Tapak.
///
/// Log entries are stored in [TapakStore] and visible in the Tapak Logs screen.
/// Each entry is also printed to the console in the same boxed format as the
/// HTTP console output.
///
/// ```dart
/// TapakLog.debug('remote_config', 'initialization started');
/// TapakLog.warning('auth', 'token expires in 5 minutes');
/// TapakLog.danger('payment', 'gateway timeout');
/// ```
class TapakLog {
  const TapakLog._();

  static void debug(String title, String message) =>
      _record(title, message, TapakLogLevel.debug);

  static void info(String title, String message) =>
      _record(title, message, TapakLogLevel.info);

  static void success(String title, String message) =>
      _record(title, message, TapakLogLevel.success);

  static void warning(String title, String message) =>
      _record(title, message, TapakLogLevel.warning);

  static void danger(String title, String message) =>
      _record(title, message, TapakLogLevel.danger);

  // ---------------------------------------------------------------------------

  static void _record(String title, String message, TapakLogLevel level) {
    try {
      final entry = TapakLogEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        message: message,
        level: level,
        time: DateTime.now(),
      );
      TapakStore.instance.addLog(entry);
      _printToConsole(entry);
    } catch (_) {
      // Tapak must never crash the host app.
    }
  }

  // Same width constant as TapakPrinter for visual consistency.
  static const _w = 64;

  static void _printToConsole(TapakLogEntry entry) {
    final t = entry.time;
    final timeStr =
        '${_p(t.hour)}:${_p(t.minute)}:${_p(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';

    // Header embeds level, title and timestamp — padded to _w with ─.
    final label =
        '[Tapak] ${entry.level.icon} ${entry.level.label}  [${entry.title}]  $timeStr';
    final top = '╔═ $label '.padRight(_w, '═');
    final bot = '╚${'═' * (_w - 1)}';

    final msgLines = _wrap(entry.message, _w - 3).map((l) => '║  $l').toList();

    if (!kIsWeb && stdout.hasTerminal) {
      try {
        const reset = '\x1B[0m';
        const bold = '\x1B[1m';
        final c = entry.level.ansi;
        final buf = StringBuffer()..writeln('$c$bold$top$reset');
        for (final l in msgLines) {
          buf.writeln('$c$l$reset');
        }
        buf.write('$c$bot$reset');
        stdout.writeln(buf.toString());
      } catch (_) {}
    } else {
      try {
        final buf = StringBuffer()..writeln(top);
        for (final l in msgLines) {
          buf.writeln(l);
        }
        buf.write(bot);
        debugPrint(buf.toString());
      } catch (_) {}
    }
  }

  static List<String> _wrap(String text, int max) {
    if (text.length <= max) return [text];
    final lines = <String>[];
    var s = text;
    while (s.length > max) {
      var cut = s.lastIndexOf(' ', max);
      if (cut <= 0) cut = max;
      lines.add(s.substring(0, cut));
      s = s.substring(cut).trimLeft();
    }
    if (s.isNotEmpty) lines.add(s);
    return lines;
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}
