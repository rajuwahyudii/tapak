// ignore_for_file: deprecated_library_use
import 'package:flutter/material.dart';
import '../../model/http_transaction.dart';

/// Colored pill badge showing HTTP status code, loading state, or error.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.statusCode,
  });

  final TransactionStatus status;
  final int? statusCode;

  static Color _colorFor(int? code, TransactionStatus status) {
    if (status == TransactionStatus.pending) return const Color(0xFF9E9E9E);
    if (code == null) return const Color(0xFFF44336);
    if (code >= 200 && code < 300) return const Color(0xFF4CAF50);
    if (code >= 300 && code < 400) return const Color(0xFF2196F3);
    if (code >= 400 && code < 500) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    if (status == TransactionStatus.pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF9E9E9E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    final label = statusCode?.toString() ?? 'ERR';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _colorFor(statusCode, status),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
