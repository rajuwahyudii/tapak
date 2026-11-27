import 'dart:convert';

import 'package:http/http.dart';

import '../logger/tapak_printer.dart';
import '../model/http_transaction.dart';
import '../store/tapak_store.dart';

/// An `http` [Client] wrapper that records every request/response into
/// [TapakStore] and/or prints to the debug console.
///
/// ```dart
/// import 'package:flutter/foundation.dart';
/// import 'package:http/http.dart' as http;
///
/// final client = TapakHttpClient(
///   http.Client(),
///   enabled: kDebugMode,      // show in the in-app UI
///   logToConsole: kDebugMode, // also print to the debug console
/// );
///
/// // Use exactly like a regular http.Client:
/// final response = await client.get(Uri.parse('https://example.com/api'));
///
/// // Close when done (e.g. in dispose):
/// client.close();
/// ```
///
/// Both flags are independent — use either or both.
class TapakHttpClient extends BaseClient {
  TapakHttpClient(
    this._inner, {
    TapakStore? store,
    this.enabled = true,
    this.logToConsole = false,
  }) : _store = store ?? TapakStore.instance;

  final Client _inner;
  final TapakStore _store;

  /// Records transactions into [TapakStore] for the in-app inspector UI.
  final bool enabled;

  /// Prints every request and response to the debug console via [debugPrint].
  /// Set to [kDebugMode] to suppress output in release builds.
  final bool logToConsole;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (!enabled && !logToConsole) return _inner.send(request);

    // QA: inject simulated date as a header if set.
    // ponytail: query param injection skipped — http.BaseRequest.url is final;
    // use TapakInterceptor (Dio) if query param injection is needed.
    try {
      final sim = _store.simulatedDate;
      if (sim != null) {
        final cfg = _store.simulatedDateConfig;
        if (cfg.headerName != null) {
          request.headers[cfg.headerName!] = cfg.formatDate(sim);
        }
      }
    } catch (_) {}

    HttpTransaction? tx;
    try {
      tx = HttpTransaction(
        id: '${DateTime.now().microsecondsSinceEpoch}_${request.hashCode}',
        method: request.method,
        uri: request.url,
        requestHeaders: Map<String, dynamic>.from(request.headers),
        requestBody: _captureRequestBody(request),
        requestTime: DateTime.now(),
      );
      if (enabled) {
        _store.add(tx);
      }
      if (logToConsole) {
        TapakPrinter.request(tx, clientType: TapakClientType.http);
      }
    } catch (_) {
      // Tapak setup failed — still forward the real request.
    }

    try {
      final response = await _inner.send(request);
      final bytes = await response.stream.toBytes();

      try {
        if (tx != null) {
          tx.statusCode = response.statusCode;
          tx.responseHeaders = Map<String, dynamic>.from(response.headers);
          tx.responseBody = utf8.decode(bytes, allowMalformed: true);
          tx.responseTime = DateTime.now();
          tx.status = TransactionStatus.success;
          if (enabled) {
            _store.update(tx);
          }
          if (logToConsole) {
            TapakPrinter.response(tx, clientType: TapakClientType.http);
          }
        }
      } catch (_) {
        // Tapak recording failed — response is still returned.
      }

      return StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      try {
        if (tx != null) {
          tx.responseTime = DateTime.now();
          tx.error = e.toString();
          tx.status = TransactionStatus.error;
          if (enabled) {
            _store.update(tx);
          }
          if (logToConsole) {
            TapakPrinter.response(tx, clientType: TapakClientType.http);
          }
        }
      } catch (_) {}
      rethrow; // Real network error — always propagate to the caller.
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  static dynamic _captureRequestBody(BaseRequest request) {
    if (request is Request) {
      return request.body.isNotEmpty ? request.body : null;
    }
    if (request is MultipartRequest) {
      return request.fields.isNotEmpty
          ? '[multipart] ${request.fields}'
          : '[multipart]';
    }
    return null;
  }
}
