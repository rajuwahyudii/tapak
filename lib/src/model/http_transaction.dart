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

  Duration? get duration => responseTime?.difference(requestTime);

  String get durationText {
    final d = duration;
    if (d == null) return '—';
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }

  String get formattedRequestBody => _formatBody(requestBody);
  String get formattedResponseBody => _formatBody(responseBody);

  static String _formatBody(dynamic body) {
    if (body == null) return '';
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
