import 'dart:convert';

/// Lifecycle state of an HTTP transaction.
enum TransactionStatus { pending, success, error }

/// Represents a single HTTP request/response cycle.
class HttpTransaction {
  HttpTransaction({
    required this.id,
    required this.method,
    required this.uri,
    required this.requestHeaders,
    required this.requestTime,
    this.requestBody,
    this.status = TransactionStatus.pending,
  });

  final String id;
  final String method;
  final Uri uri;
  final Map<String, dynamic> requestHeaders;
  final dynamic requestBody;
  final DateTime requestTime;

  int? statusCode;
  Map<String, dynamic>? responseHeaders;
  dynamic responseBody;
  DateTime? responseTime;
  String? error;
  TransactionStatus status;

  /// True when this transaction was created by [TapakReplayer].
  bool isReplayed = false;

  Duration? get duration => responseTime?.difference(requestTime);

  String get durationText {
    final d = duration;
    if (d == null) return '—';
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }

  // ponytail: formatBody can be expensive (UTF-8 decode, JSON encode).
  // Cache on first access; requestBody is final, responseBody is set once.
  String? _cachedRequestBody;
  String? _cachedResponseBody;

  String get formattedRequestBody =>
      _cachedRequestBody ??= _formatBody(requestBody);

  String get formattedResponseBody {
    if (responseBody == null) return '';
    return _cachedResponseBody ??= _formatBody(responseBody);
  }

  static String _formatBody(dynamic body) {
    if (body == null) return '';
    if (body is List<int>) {
      // Byte array — decode as UTF-8 then recurse to get JSON pretty-print.
      try {
        return _formatBody(utf8.decode(body));
      } catch (_) {
        return body.toString();
      }
    }
    if (body is String) {
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
      } catch (_) {
        return body;
      }
    }
    if (body is Map || body is List) {
      return const JsonEncoder.withIndent('  ').convert(body);
    }
    return body.toString();
  }
}
