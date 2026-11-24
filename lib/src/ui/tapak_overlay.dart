import 'package:flutter/material.dart';
import '../model/http_transaction.dart';
import '../store/tapak_store.dart';
import 'tapak_inspector_screen.dart';

/// Wraps your widget tree and adds a floating Tapak launcher button.
///
/// Best placed inside [MaterialApp.builder] so the Navigator is available:
/// ```dart
/// MaterialApp(
///   builder: (context, child) => TapakOverlay(
///     enabled: kDebugMode,
///     child: child!,
///   ),
/// )
/// ```
///
/// The button shows the live request count and turns red when any request
/// has errored.
class TapakOverlay extends StatelessWidget {
  const TapakOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// Set to [kDebugMode] to only show the overlay in debug builds.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 80,
          child: _TapakFab(),
        ),
      ],
    );
  }
}

class _TapakFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TapakStore.instance,
      builder: (context, _) {
        final txs = TapakStore.instance.transactions;
        final count = txs.length;
        final hasError =
            txs.any((t) => t.status == TransactionStatus.error);

        final color = count == 0
            ? Colors.grey
            : hasError
                ? Colors.red
                : Colors.indigo;

        return FloatingActionButton.small(
          heroTag: 'tapak_overlay_fab',
          backgroundColor: color,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TapakInspectorScreen(),
            ),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
