/// Tapak — in-app HTTP inspector for Flutter.
///
/// ## Quick setup
///
/// 1. Add [TapakInterceptor] to Dio:
/// ```dart
/// final dio = Dio()
///   ..interceptors.add(TapakInterceptor(enabled: kDebugMode));
/// ```
///
/// 2. Add [TapakOverlay] inside `MaterialApp.builder`:
/// ```dart
/// MaterialApp(
///   builder: (context, child) => TapakOverlay(
///     enabled: kDebugMode,
///     child: child!,
///   ),
/// )
/// ```
///
/// Or navigate directly to [TapakInspectorScreen] from anywhere in your app.
library;

export 'src/client/tapak_http_client.dart';
export 'src/har/har_exporter.dart';
export 'src/interceptor/tapak_interceptor.dart';
export 'src/logger/tapak_log.dart';
export 'src/model/tapak_log_entry.dart';
export 'src/qa/tapak_simulated_date_config.dart';
export 'src/replay/tapak_replayer.dart';
export 'src/store/tapak_store.dart';
export 'src/logger/tapak_printer.dart' show TapakPrinter;
export 'src/model/http_transaction.dart';
export 'src/ui/tapak_detail_screen.dart';
export 'src/ui/tapak_inspector_screen.dart';
export 'src/ui/tapak_overlay.dart';
