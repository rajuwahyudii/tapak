import 'dart:developer' as developer;
import '../model/http_transaction.dart';

/// HTTP client type for logging.
enum TapakClientType { dio, http }

/// Formats [HttpTransaction] entries to the debug console.
///
/// Not part of the public API — use the [logToConsole] flag on
/// [TapakInterceptor] or [TapakHttpClient] instead.
class TapakPrinter {
  const TapakPrinter._();

  static const _name = 'Tapak Console';
  static const _w = 70; // inner width

  /// Whether to log headers. Defaults to `false`.
  static bool showHeaders = false;

  /// Custom title to show in logs. Defaults to `null` (no title).
  static String? title;

  // Box characters
  static final _top = '╔${'═' * _w}╗';
  static final _mid = '╠${'═' * _w}╣';
  static final _bot = '╚${'═' * _w}╝';

  static String _row(String s) {
    // Pad content to exactly _w - 2, then wrap with spaces
    final padded =
        s.length > _w - 2 ? s.substring(0, _w - 2) : s.padRight(_w - 2);
    return '║ $padded ║';
  }

  static void request(HttpTransaction tx, {TapakClientType? clientType}) {
    final buf = StringBuffer()..writeln(_top);

    // Title row
    final titleParts = <String>[];
    if (title != null) titleParts.add('[$title]');
    titleParts.add('>> REQUEST');
    if (clientType != null) titleParts.add('(${clientType.name})');
    buf.writeln(_row(titleParts.join('  ')));

    buf.writeln(_mid);
    _writeWrapped('${tx.method}  ${tx.uri}', buf);

    if (showHeaders && tx.requestHeaders.isNotEmpty) {
      buf.writeln(_mid);
      for (final e in tx.requestHeaders.entries) {
        _writeWrapped('${e.key}: ${e.value}', buf);
      }
    }

    final body = tx.formattedRequestBody;
    if (body.isNotEmpty && body != '{}' && body != '[]') {
      buf.writeln(_mid);
      _writeBody(body, buf);
    }

    buf.write(_bot);
    developer.log(buf.toString(), name: _name);
  }

  static void response(HttpTransaction tx, {TapakClientType? clientType}) {
    final isError = tx.status == TransactionStatus.error;
    final label = isError ? '<< ERROR' : '<< RESPONSE';
    final status = tx.statusCode?.toString() ?? 'ERR';

    final buf = StringBuffer()..writeln(_top);

    // Title row
    final titleParts = <String>[];
    if (title != null) titleParts.add('[$title]');
    titleParts.add('$label  [$status]  ${tx.durationText}');
    if (clientType != null) titleParts.add('(${clientType.name})');
    buf.writeln(_row(titleParts.join('  ')));

    buf.writeln(_mid);
    _writeWrapped('${tx.method}  ${tx.uri.path}', buf);

    if (tx.error != null) {
      buf.writeln(_mid);
      _writeWrapped('! ${tx.error}', buf);
    }

    if (showHeaders &&
        tx.responseHeaders != null &&
        tx.responseHeaders!.isNotEmpty) {
      buf.writeln(_mid);
      for (final e in tx.responseHeaders!.entries) {
        _writeWrapped('${e.key}: ${e.value}', buf);
      }
    }

    final body = tx.formattedResponseBody;
    if (body.isNotEmpty && body != '{}' && body != '[]') {
      buf.writeln(_mid);
      _writeBody(body, buf);
    }

    buf.write(_bot);
    developer.log(buf.toString(), name: _name);
  }

  static void _writeBody(String body, StringBuffer buf) {
    for (final line in body.split('\n')) {
      _writeWrapped(line, buf);
    }
  }

  /// Write text with proper wrapping to fit inside the box
  static void _writeWrapped(String text, StringBuffer buf) {
    final maxLen = _w - 2; // Content width between the spaces

    // Handle embedded newlines first
    for (final line in text.split('\n')) {
      _wrapLine(line, maxLen, buf);
    }
  }

  static void _wrapLine(String text, int maxLen, StringBuffer buf) {
    if (text.isEmpty) {
      buf.writeln(_row(''));
      return;
    }

    if (text.length <= maxLen) {
      buf.writeln(_row(text));
      return;
    }

    // Wrap long lines
    var remaining = text;
    while (remaining.isNotEmpty) {
      if (remaining.length <= maxLen) {
        buf.writeln(_row(remaining));
        break;
      }

      // Try to break at a space within maxLen
      var breakAt = remaining.lastIndexOf(' ', maxLen);
      if (breakAt <= 0) {
        // No space found, hard break at maxLen
        breakAt = maxLen;
      }

      buf.writeln(_row(remaining.substring(0, breakAt)));
      remaining = remaining.substring(breakAt).trimLeft();
    }
  }
}
