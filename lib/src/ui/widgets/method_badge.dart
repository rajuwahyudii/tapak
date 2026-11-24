import 'package:flutter/material.dart';

/// Colored pill badge for an HTTP method.
class MethodBadge extends StatelessWidget {
  const MethodBadge(this.method, {super.key});

  final String method;

  static Color colorFor(String method) => switch (method.toUpperCase()) {
        'GET' => const Color(0xFF2196F3),
        'POST' => const Color(0xFF4CAF50),
        'PUT' => const Color(0xFFFF9800),
        'PATCH' => const Color(0xFF9C27B0),
        'DELETE' => const Color(0xFFF44336),
        'HEAD' => const Color(0xFF607D8B),
        'OPTIONS' => const Color(0xFF795548),
        _ => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colorFor(method),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
