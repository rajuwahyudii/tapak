import 'package:flutter/material.dart';
import '../model/http_transaction.dart';
import '../model/tapak_log_entry.dart';

/// Central store for HTTP transactions.
///
/// Singleton, extends [ChangeNotifier] — listen to it for reactive UI updates.
class TapakStore extends ChangeNotifier {
  TapakStore._();

  static final TapakStore instance = TapakStore._();

  /// A [GlobalKey] for the root [Navigator].
  ///
  /// Set this as your [MaterialApp.navigatorKey] so the Tapak overlay button
  /// can open the inspector regardless of where it sits in the widget tree:
  /// ```dart
  /// MaterialApp(
  ///   navigatorKey: TapakStore.instance.navigatorKey,
  ///   builder: (context, child) => TapakOverlay(child: child!),
  /// )
  /// ```
  final navigatorKey = GlobalKey<NavigatorState>();

  final List<HttpTransaction> _transactions = [];

  /// Maximum number of transactions to keep in memory. Default: 200.
  int maxTransactions = 200;

  /// Whether the floating overlay button is visible. Toggle at runtime.
  bool _showButton = true;
  bool get showButton => _showButton;
  set showButton(bool value) {
    if (_showButton == value) return;
    _showButton = value;
    notifyListeners();
  }

  /// Custom base colour for the floating button.
  ///
  /// When null the button uses the automatic colour scheme:
  /// grey (no requests) → indigo (normal) → red (error).
  /// When set, the chosen colour is used for normal/idle state;
  /// red still overrides on error.
  ///
  /// ```dart
  /// TapakStore.instance.buttonColor = Colors.teal;
  /// ```
  Color? _buttonColor;
  Color? get buttonColor => _buttonColor;
  set buttonColor(Color? value) {
    if (_buttonColor == value) return;
    _buttonColor = value;
    notifyListeners();
  }

  /// Theme mode for the inspector UI.
  /// Defaults to [ThemeMode.system] (follows the device setting).
  ThemeMode _inspectorThemeMode = ThemeMode.system;
  ThemeMode get inspectorThemeMode => _inspectorThemeMode;
  set inspectorThemeMode(ThemeMode value) {
    if (_inspectorThemeMode == value) return;
    _inspectorThemeMode = value;
    notifyListeners();
  }

  // ponytail: recreating a reversed+unmodifiable list on every access is O(n)
  // and happens on every ListenableBuilder rebuild. Cache and invalidate.
  List<HttpTransaction>? _cachedTransactions;

  /// Transactions in reverse-chronological order (newest first).
  List<HttpTransaction> get transactions => _cachedTransactions ??=
      List.unmodifiable(_transactions.reversed.toList());

  // Batch rapid add/update calls into one notification per microtask so the
  // list doesn't rebuild twice per request (once on add, once on response).
  // ponytail: microtask batching ceiling — won't coalesce calls separated by
  // an await; use a debounce timer if sub-frame batching is needed.
  bool _notifyScheduled = false;

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Future.microtask(() {
      _notifyScheduled = false;
      if (hasListeners) notifyListeners();
    });
  }

  void add(HttpTransaction tx) {
    try {
      _transactions.add(tx);
      if (_transactions.length > maxTransactions) _transactions.removeAt(0);
      _cachedTransactions = null;
      _scheduleNotify();
    } catch (_) {}
  }

  /// Call after mutating a transaction in-place to notify listeners.
  void update(HttpTransaction tx) {
    try {
      _cachedTransactions = null;
      _scheduleNotify();
    } catch (_) {}
  }

  void clear() {
    try {
      _transactions.clear();
      _cachedTransactions = null;
      notifyListeners();
    } catch (_) {}
  }

  HttpTransaction? findById(String id) {
    // ponytail: linear scan; fine for ≤200 items (the maxTransactions cap).
    // Switch to Map<String, HttpTransaction> index if cap grows significantly.
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Custom logs
  // ---------------------------------------------------------------------------

  final List<TapakLogEntry> _logs = [];

  /// Maximum number of log entries to keep in memory. Default: 500.
  int maxLogs = 500;

  List<TapakLogEntry>? _cachedLogs;

  /// Log entries in reverse-chronological order (newest first).
  List<TapakLogEntry> get logs =>
      _cachedLogs ??= List.unmodifiable(_logs.reversed.toList());

  void addLog(TapakLogEntry entry) {
    try {
      _logs.add(entry);
      if (_logs.length > maxLogs) _logs.removeAt(0);
      _cachedLogs = null;
      _scheduleNotify();
    } catch (_) {}
  }

  void clearLogs() {
    try {
      _logs.clear();
      _cachedLogs = null;
      notifyListeners();
    } catch (_) {}
  }
}
