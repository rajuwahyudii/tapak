import 'dart:async';

import 'package:flutter/material.dart';

import '../model/http_transaction.dart';
import '../store/tapak_store.dart';
import 'tapak_inspector_screen.dart';

// Rendered size of the FAB — also used for drag-clamp math.
const _kFabSize = 52.0;

/// Wraps your widget tree and adds a draggable iOS-style Tapak launcher button.
///
/// Works in [MaterialApp.builder] with no extra setup:
/// ```dart
/// MaterialApp(
///   builder: (context, child) => TapakOverlay(
///     enabled: kDebugMode,
///     child: child!,
///   ),
/// )
/// ```
///
/// Toggle the button at runtime via [TapakStore.instance.showButton].
/// Set a custom colour via [TapakStore.instance.buttonColor].
class TapakOverlay extends StatefulWidget {
  const TapakOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// Set to [kDebugMode] to only show the overlay in debug builds.
  final bool enabled;

  @override
  State<TapakOverlay> createState() => _TapakOverlayState();
}

class _TapakOverlayState extends State<TapakOverlay> {
  bool _showInspector = false;
  Offset? _fabOffset;
  final _inspectorNavKey = GlobalKey<NavigatorState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Right edge, vertically centred — initialised once.
    if (_fabOffset == null) {
      final size = MediaQuery.of(context).size;
      _fabOffset = Offset(
        size.width - _kFabSize - 8,
        (size.height - _kFabSize) / 2,
      );
    }
  }

  void _openInspector() => setState(() => _showInspector = true);
  void _closeInspector() => setState(() => _showInspector = false);

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_showInspector)
          Positioned.fill(
            child: _InspectorOverlay(
              navKey: _inspectorNavKey,
              onClose: _closeInspector,
            ),
          ),
        if (!_showInspector)
          ListenableBuilder(
            listenable: TapakStore.instance,
            builder: (context, _) {
              if (!TapakStore.instance.showButton) {
                return const SizedBox.shrink();
              }

              final txs = TapakStore.instance.transactions;
              final count = txs.length;
              final hasError =
                  txs.any((t) => t.status == TransactionStatus.error);
              final custom = TapakStore.instance.buttonColor;

              return Positioned(
                left: _fabOffset!.dx,
                top: _fabOffset!.dy,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => setState(() {
                    _fabOffset = Offset(
                      (_fabOffset!.dx + d.delta.dx)
                          .clamp(0.0, size.width - _kFabSize),
                      (_fabOffset!.dy + d.delta.dy)
                          .clamp(0.0, size.height - _kFabSize),
                    );
                  }),
                  child: _IosFab(
                    count: count,
                    hasError: hasError,
                    customColor: custom,
                    onTap: _openInspector,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// iOS AssistiveTouch–style FAB
// ---------------------------------------------------------------------------

class _IosFab extends StatefulWidget {
  const _IosFab({
    required this.count,
    required this.hasError,
    required this.customColor,
    required this.onTap,
  });

  final int count;
  final bool hasError;
  final Color? customColor;
  final VoidCallback onTap;

  @override
  State<_IosFab> createState() => _IosFabState();
}

class _IosFabState extends State<_IosFab> {
  bool _pressed = false;
  bool _idle = false;
  Timer? _idleTimer;

  // iOS AssistiveTouch dims to ~40% when unused; wakes on any interaction.
  void _wake() {
    _idleTimer?.cancel();
    if (_idle) setState(() => _idle = false);
    _idleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _idle = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _wake();
  }

  @override
  void didUpdateWidget(_IosFab old) {
    super.didUpdateWidget(old);
    // A new request arriving counts as activity — wake the button.
    if (old.count != widget.count) _wake();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // iOS system colours
    final baseColor = widget.hasError
        ? const Color(0xFFFF3B30) // iOS red
        : (widget.customColor ??
            (widget.count == 0
                ? const Color(0xFF8E8E93) // iOS grey
                : const Color(0xFF007AFF))); // iOS blue

    final highlightColor = Color.lerp(baseColor, Colors.white, 0.18)!;

    return Semantics(
      button: true,
      label: 'Open Tapak inspector, ${widget.count} requests',
      child: GestureDetector(
        onTapDown: (_) {
          _wake();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          opacity: _idle ? 0.38 : 1.0,
          child: AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: SizedBox(
              width: _kFabSize,
              height: _kFabSize,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    // Coloured ambient glow
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.45),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                    // Mid-distance shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    // Crisp contact shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        highlightColor.withValues(alpha: 0.92),
                        baseColor.withValues(alpha: 0.80),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 0.75,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Glass highlight arc — top-left shimmer
                      Positioned(
                        top: 5,
                        left: 9,
                        right: 9,
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.38),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Count label
                      Center(
                        child: Text(
                          widget.count > 99 ? '99+' : '${widget.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            height: 1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _InspectorOverlay extends StatelessWidget {
  const _InspectorOverlay({required this.navKey, required this.onClose});

  final GlobalKey<NavigatorState> navKey;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navKey.currentState?.canPop() == true) {
          navKey.currentState!.pop();
        } else {
          onClose();
        }
      },
      child: ListenableBuilder(
        listenable: TapakStore.instance,
        builder: (context, _) {
          final mode = TapakStore.instance.inspectorThemeMode;
          final platformBrightness = MediaQuery.platformBrightnessOf(context);
          final brightness = switch (mode) {
            ThemeMode.light => Brightness.light,
            ThemeMode.dark => Brightness.dark,
            ThemeMode.system => platformBrightness,
          };
          return Theme(
            data: brightness == Brightness.dark
                ? ThemeData.dark(useMaterial3: true)
                : ThemeData.light(useMaterial3: true),
            child: Material(
              child: Navigator(
                key: navKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => TapakInspectorScreen(onClose: onClose),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
