import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/http_transaction.dart';
import '../store/tapak_store.dart';

/// Replays an [HttpTransaction] using the `http` package and records the
/// result as a new transaction in [TapakStore].
///
/// Returns the newly created [HttpTransaction] so the caller can navigate to
/// its detail screen.
class TapakReplayer {
  const TapakReplayer._();

  static Future<HttpTransaction> replay(HttpTransaction original) async {
    // Clone the original transaction as a fresh pending entry.
    final id = '${DateTime.now().microsecondsSinceEpoch}_replay';
    final tx = HttpTransaction(
      id: id,
      method: original.method,
      uri: original.uri,
      requestHeaders: Map<String, dynamic>.from(original.requestHeaders),
      requestBody: original.requestBody,
      requestTime: DateTime.now(),
    );
    TapakStore.instance.add(tx);

    // Mark the new transaction as a replay so the UI can flag it.
    tx.isReplayed = true;

    try {
      final headers = {
        for (final e in original.requestHeaders.entries)
          e.key: e.value.toString(),
      };

      // Serialise request body to string if needed.
      String? bodyStr;
      if (original.requestBody != null) {
        if (original.requestBody is String) {
          bodyStr = original.requestBody as String;
        } else if (original.requestBody is Map ||
            original.requestBody is List) {
          bodyStr = jsonEncode(original.requestBody);
          headers.putIfAbsent('Content-Type', () => 'application/json');
        }
      }

      final method = original.method.toUpperCase();
      final uri = original.uri;

      final response = await _send(method, uri, headers, bodyStr);

      tx.statusCode = response.statusCode;
      tx.responseHeaders = response.headers.map((k, v) => MapEntry(k, v));
      // Try to decode as JSON; fall back to raw string.
      tx.responseBody = _parseBody(response);
      tx.responseTime = DateTime.now();
      tx.status = response.statusCode >= 200 && response.statusCode < 300
          ? TransactionStatus.success
          : TransactionStatus.error;
    } catch (e) {
      tx.error = e.toString();
      tx.responseTime = DateTime.now();
      tx.status = TransactionStatus.error;
    }

    TapakStore.instance.update(tx);
    return tx;
  }

  static Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    return switch (method) {
      'POST' => http.post(uri, headers: headers, body: body),
      'PUT' => http.put(uri, headers: headers, body: body),
      'PATCH' => http.patch(uri, headers: headers, body: body),
      'DELETE' => http.delete(uri, headers: headers, body: body),
      'HEAD' => http.head(uri, headers: headers),
      _ => http.get(uri, headers: headers),
    };
  }

  static dynamic _parseBody(http.Response response) {
    final body = response.body;
    if (body.isEmpty) return null;
    final ct = response.headers['content-type'] ?? '';
    if (ct.contains('application/json')) {
      try {
        return jsonDecode(body);
      } catch (_) {}
    }
    return body;
  }
}
