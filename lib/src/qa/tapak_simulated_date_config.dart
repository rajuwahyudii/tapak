/// Defines how the simulated date is injected into outgoing requests.
///
/// Assign to [TapakStore.instance.simulatedDateConfig] to customise injection.
/// The defaults inject the date as an HTTP header named `X-Simulated-Date`.
///
/// ```dart
/// // Inject as a query parameter (Dio / TapakInterceptor only):
/// TapakStore.instance.simulatedDateConfig = const TapakSimulatedDateConfig(
///   headerName: null,
///   queryParamName: 'currentDate',
/// );
///
/// // Inject as both header and query param:
/// TapakStore.instance.simulatedDateConfig = const TapakSimulatedDateConfig(
///   headerName: 'X-Simulated-Date',
///   queryParamName: 'simulatedDate',
/// );
/// ```
class TapakSimulatedDateConfig {
  const TapakSimulatedDateConfig({
    this.headerName = 'X-Simulated-Date',
    this.queryParamName,
    this.format,
  });

  /// HTTP header name to inject. `null` disables header injection.
  /// Defaults to `'X-Simulated-Date'`.
  final String? headerName;

  /// Query parameter name to inject. `null` (default) disables query param injection.
  ///
  /// Supported by [TapakInterceptor] (Dio) only.
  /// [TapakHttpClient] skips query param injection because
  /// `http.BaseRequest.url` is immutable after the request is constructed.
  final String? queryParamName;

  /// Custom formatter for the date value sent to the server.
  /// Defaults to ISO 8601 UTC, e.g. `2024-01-15T00:00:00.000Z`.
  final String Function(DateTime)? format;

  /// Formats [date] using [format] if provided, otherwise ISO 8601 UTC.
  String formatDate(DateTime date) =>
      format != null ? format!(date) : date.toUtc().toIso8601String();
}
