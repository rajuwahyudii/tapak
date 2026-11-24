import 'package:flutter/foundation.dart';
import '../model/http_transaction.dart';

/// Formats [HttpTransaction] entries to the debug console via [debugPrint].
///
/// Not part of the public API — use the [logToConsole] flag on
/// [TapakInterceptor] or [TapakHttpClient] instead.
class TapakPrinter {
  const TapakPrinter._();

  static const _tag = '[Tapak]';
  static const _div = '──────────────────────────────────────────────────────';

  static void request(HttpTransaction tx) {
    _p('┌── Request $_div');
    _p('│  ${tx.method}  ${tx.uri}');
    _headers(tx.requestHeaders);
    _body(tx.formattedRequestBody);
    _p('└$_div─');
  }

  static void response(HttpTransaction tx) {
    final label = tx.status == TransactionStatus.error ? 'Error  ' : 'Response';
    final status = tx.statusCode?.toString() ?? 'ERR';
    _p('┌── $label $_div');
    _p('│  $status  ${tx.durationText}  ${tx.method}  ${tx.uri.host}${tx.uri.path}');
    if (tx.error != null) _p('│  ⚠  ${tx.error}');
    _headers(tx.responseHeaders ?? {});
    _body(tx.formattedResponseBody);
    _p('└$_div─');
  }

  static void _headers(Map<String, dynamic> h) {
    if (h.isEmpty) return;
    _p('│  Headers:');
    for (final e in h.entries) {
      _p('│    ${e.key}: ${e.value}');
    }
  }

  static void _body(String body) {
    if (body.isEmpty) return;
    _p('│  Body:');
    // Split by line so each debugPrint call stays within the 1024-char limit.
    for (final line in body.split('\n')) {
      _p('│    $line');
    }
  }

  static void _p(String line) => debugPrint('$_tag $line');
}
