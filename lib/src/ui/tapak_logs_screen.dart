// ignore_for_file: deprecated_library_use
import 'package:flutter/material.dart';

import '../model/tapak_log_entry.dart';
import '../store/tapak_store.dart';

/// Full-screen list of custom [TapakLog] entries.
class TapakLogsScreen extends StatefulWidget {
  const TapakLogsScreen({super.key});

  @override
  State<TapakLogsScreen> createState() => _TapakLogsScreenState();
}

class _TapakLogsScreenState extends State<TapakLogsScreen> {
  TapakLogLevel? _filter; // null = show all

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text('All custom log entries will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              TapakStore.instance.clearLogs();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          // Level filter
          PopupMenuButton<TapakLogLevel?>(
            icon: Icon(
              Icons.filter_list,
              color: _filter?.color,
            ),
            tooltip: 'Filter by level',
            initialValue: _filter,
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              _filterItem(null, 'All levels', context),
              ...TapakLogLevel.values
                  .map((l) => _filterItem(l, l.label, context)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: TapakStore.instance,
        builder: (context, _) {
          final all = TapakStore.instance.logs;
          final items = _filter == null
              ? all
              : all.where((e) => e.level == _filter).toList();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    all.isEmpty ? Icons.terminal : Icons.filter_list_off,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withAlpha(76),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    all.isEmpty ? 'No logs yet' : 'No matches',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (all.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Use TapakLog.debug(), .warning(), .danger() etc.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _LogTile(entry: items[i]),
          );
        },
      ),
    );
  }

  PopupMenuItem<TapakLogLevel?> _filterItem(
    TapakLogLevel? value,
    String label,
    BuildContext context,
  ) {
    return PopupMenuItem<TapakLogLevel?>(
      value: value,
      child: Row(
        children: [
          if (value != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: value.color,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(width: 20),
          Text(label),
          const Spacer(),
          if (_filter == value)
            Icon(Icons.check,
                size: 16, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});
  final TapakLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final t = e.time;
    final timeLabel =
        '${_p(t.hour)}:${_p(t.minute)}:${_p(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level indicator dot
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: e.level.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LevelBadge(level: e.level),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '[${e.title}]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                SelectableText(
                  e.message,
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeLabel,
            style: TextStyle(fontSize: 11, color: subtitleColor),
          ),
        ],
      ),
    );
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final TapakLogLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: level.color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: level.color.withAlpha(120), width: 0.75),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: level.color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
