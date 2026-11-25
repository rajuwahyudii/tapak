import 'package:flutter/foundation.dart';
import '../model/http_transaction.dart';

/// HTTP client type for logging.
enum TapakClientType { dio, http }

/// Formats [HttpTransaction] entries to the debug console.
///
/// Not part of the public API — use the [logToConsole] flag on
/// [TapakInterceptor] or [TapakHttpClient] instead.
class TapakPrinter {
  const TapakPrinter._();

  static const _w = 64; // total width of horizontal rule lines

  /// Whether to log headers. Defaults to `false`.
  static bool showHeaders = false;

  /// Custom title shown in every log line. Defaults to `null`.
  static String? title;

  // ── Box helpers ─────────────────────────────────────────────────────────────

  /// Top border with label embedded: ╔═ [label] ══════
  static String _top(String label) => '╔═ $label '.padRight(_w, '═');

  /// Left-border content line: ║  text
  static String _row(String s) => '║  $s';

  /// Section divider: ╠════════
  static String _div() => '╠${'═' * (_w - 1)}';

  /// Bottom border: ╚════════
  static String _bot() => '╚${'═' * (_w - 1)}';

  // ── Public API ───────────────────────────────────────────────────────────────

  static void request(HttpTransaction tx, {TapakClientType? clientType}) {
    final parts = <String>[];
    if (title != null) parts.add('[$title]');
    parts.add('>> REQUEST');
    if (clientType != null) parts.add('(${clientType.name})');

    final buf = StringBuffer()
      ..writeln(_top('[Tapak] ${parts.join('  ')}'))
      ..writeln(_row('${tx.method}  ${tx.uri}'));

    if (showHeaders && tx.requestHeaders.isNotEmpty) {
      buf.writeln(_div());
      for (final e in tx.requestHeaders.entries) {
        _appendWrapped('${e.key}: ${e.value}', buf);
      }
    }

    final body = tx.formattedRequestBody;
    if (body.isNotEmpty && body != '{}' && body != '[]') {
      buf.writeln(_div());
      _appendBody(body, buf);
    }

    buf.write(_bot());
    debugPrint(buf.toString());
  }

  static void response(HttpTransaction tx, {TapakClientType? clientType}) {
    final isError = tx.status == TransactionStatus.error;
    final label = isError ? '<< ERROR' : '<< RESPONSE';
    final status = tx.statusCode?.toString() ?? 'ERR';

    final parts = <String>[];
    if (title != null) parts.add('[$title]');
    parts.add('$label  [$status]  ${tx.durationText}');
    if (clientType != null) parts.add('(${clientType.name})');

    final buf = StringBuffer()
      ..writeln(_top('[Tapak] ${parts.join('  ')}'))
      ..writeln(_row('${tx.method}  ${tx.uri.path}'));

    if (tx.error != null) {
      buf.writeln(_div());
      _appendWrapped('! ${tx.error!}', buf);
    }

    if (showHeaders &&
        tx.responseHeaders != null &&
        tx.responseHeaders!.isNotEmpty) {
      buf.writeln(_div());
      for (final e in tx.responseHeaders!.entries) {
        _appendWrapped('${e.key}: ${e.value}', buf);
      }
    }

    final body = tx.formattedResponseBody;
    if (body.isNotEmpty && body != '{}' && body != '[]') {
      buf.writeln(_div());
      _appendBody(body, buf);
    }

    buf.write(_bot());
    debugPrint(buf.toString());
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  static void _appendBody(String body, StringBuffer buf) {
    const maxLines = 100;
    final lines = body.split('\n');
    final limit = lines.length > maxLines ? maxLines : lines.length;
    for (var i = 0; i < limit; i++) {
      _appendWrapped(lines[i], buf);
    }
    if (lines.length > maxLines) {
      buf.writeln(_row('… ${lines.length - maxLines} more lines (truncated)'));
    }
  }

  static void _appendWrapped(String text, StringBuffer buf) {
    const maxLen = _w - 3;
    if (text.length <= maxLen) {
      buf.writeln(_row(text));
      return;
    }
    var remaining = text;
    while (remaining.isNotEmpty) {
      if (remaining.length <= maxLen) {
        buf.writeln(_row(remaining));
        break;
      }
      var cut = remaining.lastIndexOf(' ', maxLen);
      if (cut <= 0) cut = maxLen;
      buf.writeln(_row(remaining.substring(0, cut)));
      remaining = remaining.substring(cut).trimLeft();
    }
  }
}
