import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scrollable monospace body viewer with a one-tap copy button.
class BodyViewer extends StatelessWidget {
  const BodyViewer({
    super.key,
    required this.body,
    this.emptyLabel = 'Empty body',
  });

  final String body;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 48, 16),
          child: SelectableText(
            body,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy to clipboard',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: body));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
