import 'package:dio/dio.dart';

import '../logger/tapak_printer.dart';
import '../model/http_transaction.dart';
import '../store/tapak_store.dart';

/// Dio [Interceptor] that records every request/response into [TapakStore]
/// and/or prints to the debug console.
///
/// ```dart
/// import 'package:flutter/foundation.dart';
///
/// final dio = Dio()
///   ..interceptors.add(
///     TapakInterceptor(
///       enabled: kDebugMode,      // show in the in-app UI
///       logToConsole: kDebugMode, // also print to the debug console
///     ),
///   );
/// ```
///
/// Both flags are independent — use either or both.
class TapakInterceptor extends Interceptor {
  TapakInterceptor({
    TapakStore? store,
    this.enabled = true,
    this.logToConsole = false,
  }) : _store = store ?? TapakStore.instance;

  final TapakStore _store;

  /// Records transactions into [TapakStore] for the in-app inspector UI.
  final bool enabled;

  /// Prints every request and response to the debug console via [debugPrint].
  /// Set to [kDebugMode] to suppress output in release builds.
  final bool logToConsole;

  static const _kIdKey = '_tapak_tx_id';
  // Carry the HttpTransaction object through the Dio lifecycle via extra so
  // console-only mode works without a separate tracking map.
  static const _kTxKey = '_tapak_tx';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      if (enabled || logToConsole) {
        final id =
            '${DateTime.now().microsecondsSinceEpoch}_${options.hashCode}';
        final tx = HttpTransaction(
          id: id,
          method: options.method,
          uri: options.uri,
          requestHeaders: Map<String, dynamic>.from(options.headers),
          requestBody: options.data,
          requestTime: DateTime.now(),
        );

        options.extra[_kIdKey] = id;
        options.extra[_kTxKey] = tx;

        if (enabled) {
          _store.add(tx);
        }
        if (logToConsole) {
          TapakPrinter.request(tx, clientType: TapakClientType.dio);
        }
      }

      // QA: inject simulated date if set.
      final sim = _store.simulatedDate;
      if (sim != null) {
        final cfg = _store.simulatedDateConfig;
        final formatted = cfg.formatDate(sim);
        if (cfg.headerName != null) {
          options.headers[cfg.headerName!] = formatted;
        }
        if (cfg.queryParamName != null) {
          options.queryParameters[cfg.queryParamName!] = formatted;
        }
      }
    } catch (_) {
      // Never let Tapak break a request.
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      if (enabled || logToConsole) {
        final tx = _resolveTx(response.requestOptions);
        if (tx != null) {
          tx.statusCode = response.statusCode;
          tx.responseHeaders = _flattenHeaders(response.headers.map);
          tx.responseBody = response.data;
          tx.responseTime = DateTime.now();
          tx.status = TransactionStatus.success;

          if (enabled) {
            _store.update(tx);
          }
          if (logToConsole) {
            TapakPrinter.response(tx, clientType: TapakClientType.dio);
          }
        }
      }
    } catch (_) {
      // Never let Tapak break a response.
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      if (enabled || logToConsole) {
        final tx = _resolveTx(err.requestOptions);
        if (tx != null) {
          tx.statusCode = err.response?.statusCode;
          tx.responseBody = err.response?.data;
          tx.responseTime = DateTime.now();
          tx.error = err.message;
          tx.status = TransactionStatus.error;

          if (enabled) {
            _store.update(tx);
          }
          if (logToConsole) {
            TapakPrinter.response(tx, clientType: TapakClientType.dio);
          }
        }
      }
    } catch (_) {
      // Never let Tapak break an error handler.
    }
    handler.next(err);
  }

  HttpTransaction? _resolveTx(RequestOptions options) {
    // Prefer the in-memory store (always up-to-date reference).
    // Fall back to the object stored in extra for console-only mode.
    final id = options.extra[_kIdKey] as String?;
    if (id != null && enabled) return _store.findById(id);
    return options.extra[_kTxKey] as HttpTransaction?;
  }

  /// Dio headers are `Map<String, List<String>>`; flatten to `Map<String, String>`.
  static Map<String, dynamic> _flattenHeaders(
    Map<String, List<String>> headers,
  ) =>
      headers.map((k, v) => MapEntry(k, v.join(', ')));
}
