import 'dart:convert';

import '../model/http_transaction.dart';

/// Converts [HttpTransaction] records to the HAR 1.2 format.
///
/// Spec: https://w3c.github.io/web-performance/specs/HAR/Overview.html
///
/// Usage:
/// ```dart
/// final json = HarExporter.toHarString(TapakStore.instance.transactions);
/// ```
class HarExporter {
  const HarExporter._();

  /// Serialises [transactions] to a pretty-printed HAR JSON string.
  static String toHarString(List<HttpTransaction> transactions) =>
      const JsonEncoder.withIndent('  ').convert(toHarMap(transactions));

  /// Returns the HAR document as a plain [Map] (useful for custom serialisation).
  static Map<String, dynamic> toHarMap(List<HttpTransaction> transactions) {
    return {
      'log': {
        'version': '1.2',
        'creator': {'name': 'tapak', 'version': '0.1.0'},
        'entries': [
          for (final tx in transactions) _entryFromTransaction(tx),
        ],
      },
    };
  }

  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _entryFromTransaction(HttpTransaction tx) {
    return {
      'startedDateTime': tx.requestTime.toIso8601String(),
      'time': tx.duration?.inMilliseconds ?? -1,
      'request': _buildRequest(tx),
      'response': _buildResponse(tx),
      'cache': <String, dynamic>{},
      'timings': {
        'send': 0,
        'wait': tx.duration?.inMilliseconds ?? -1,
        'receive': 0,
      },
    };
  }

  static Map<String, dynamic> _buildRequest(HttpTransaction tx) {
    return {
      'method': tx.method.toUpperCase(),
      'url': tx.uri.toString(),
      'httpVersion': 'HTTP/1.1',
      'cookies': <dynamic>[],
      'headers': _headersToList(tx.requestHeaders),
      'queryString': tx.uri.queryParameters.entries
          .map((e) => {'name': e.key, 'value': e.value})
          .toList(),
      if (tx.requestBody != null)
        'postData': _buildPostData(tx.requestBody, tx.requestHeaders),
      'headersSize': -1,
      'bodySize': tx.requestBody != null ? _bodyBytes(tx.requestBody) : -1,
    };
  }

  static Map<String, dynamic> _buildResponse(HttpTransaction tx) {
    // Pending or errored transactions have no status code yet.
    if (tx.statusCode == null) {
      return {
        'status': 0,
        'statusText': tx.error ?? 'pending',
        'httpVersion': 'HTTP/1.1',
        'cookies': <dynamic>[],
        'headers': <dynamic>[],
        'content': {'size': -1, 'mimeType': 'x-unknown'},
        'redirectURL': '',
        'headersSize': -1,
        'bodySize': -1,
      };
    }

    final mimeType =
        _mimeType(tx.responseHeaders) ?? 'application/octet-stream';
    final bodyText = _rawBodyText(tx.responseBody);

    return {
      'status': tx.statusCode!,
      'statusText': _statusText(tx.statusCode!),
      'httpVersion': 'HTTP/1.1',
      'cookies': <dynamic>[],
      'headers': _headersToList(tx.responseHeaders ?? {}),
      'content': {
        'size': bodyText.isEmpty ? -1 : bodyText.length,
        'mimeType': mimeType,
        if (bodyText.isNotEmpty) 'text': bodyText,
      },
      'redirectURL': '',
      'headersSize': -1,
      'bodySize': bodyText.isEmpty ? -1 : bodyText.length,
    };
  }

  static List<Map<String, String>> _headersToList(
    Map<String, dynamic> headers,
  ) =>
      headers.entries
          .map((e) => {'name': e.key, 'value': e.value.toString()})
          .toList();

  static Map<String, dynamic> _buildPostData(
    dynamic body,
    Map<String, dynamic> requestHeaders,
  ) {
    final mime = _mimeType(requestHeaders) ?? 'application/octet-stream';
    return {'mimeType': mime, 'text': _rawBodyText(body)};
  }

  /// Raw compact body text for HAR — no pretty-printing so the string doesn't
  /// double-escape when serialised into the outer HAR JSON.
  static String _rawBodyText(dynamic body) {
    if (body == null) return '';
    if (body is List<int>) {
      try {
        return utf8.decode(body);
      } catch (_) {
        return body.toString();
      }
    }
    if (body is String) return body;
    if (body is Map || body is List) return jsonEncode(body);
    return body.toString();
  }

  static String? _mimeType(Map<String, dynamic>? headers) {
    if (headers == null) return null;
    for (final key in headers.keys) {
      if (key.toLowerCase() == 'content-type') {
        return headers[key].toString().split(';').first.trim();
      }
    }
    return null;
  }

  static int _bodyBytes(dynamic body) {
    final s = switch (body) {
      String s => s,
      Map _ || List _ => jsonEncode(body),
      _ => body.toString(),
    };
    // HAR spec wants byte count; utf8 length is a reasonable approximation.
    return utf8.encode(s).length;
  }

  static String _statusText(int code) =>
      const {
        100: 'Continue',
        101: 'Switching Protocols',
        200: 'OK',
        201: 'Created',
        202: 'Accepted',
        204: 'No Content',
        206: 'Partial Content',
        301: 'Moved Permanently',
        302: 'Found',
        304: 'Not Modified',
        400: 'Bad Request',
        401: 'Unauthorized',
        403: 'Forbidden',
        404: 'Not Found',
        405: 'Method Not Allowed',
        409: 'Conflict',
        410: 'Gone',
        422: 'Unprocessable Entity',
        429: 'Too Many Requests',
        500: 'Internal Server Error',
        502: 'Bad Gateway',
        503: 'Service Unavailable',
        504: 'Gateway Timeout',
      }[code] ??
      '';
}
