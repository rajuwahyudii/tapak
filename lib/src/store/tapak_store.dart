import 'package:flutter/foundation.dart';
import '../model/http_transaction.dart';

/// Central store for HTTP transactions.
///
/// Singleton, extends [ChangeNotifier] — listen to it for reactive UI updates.
class TapakStore extends ChangeNotifier {
  TapakStore._();

  static final TapakStore instance = TapakStore._();

  final List<HttpTransaction> _transactions = [];

  /// Maximum number of transactions to keep in memory. Default: 200.
  int maxTransactions = 200;

  /// Transactions in reverse-chronological order (newest first).
  List<HttpTransaction> get transactions =>
      List.unmodifiable(_transactions.reversed.toList());

  void add(HttpTransaction tx) {
    _transactions.add(tx);
    // ponytail: drop oldest when over cap. O(n) shift on a list capped at 200
    // is negligible; use a ring buffer if the cap grows to thousands.
    if (_transactions.length > maxTransactions) _transactions.removeAt(0);
    notifyListeners();
  }

  /// Call after mutating a transaction in-place to notify listeners.
  void update(HttpTransaction tx) => notifyListeners();

  void clear() {
    _transactions.clear();
    notifyListeners();
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
}
