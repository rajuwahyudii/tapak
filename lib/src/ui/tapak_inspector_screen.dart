import 'package:flutter/material.dart';

import '../model/http_transaction.dart';
import '../store/tapak_store.dart';
import 'tapak_detail_screen.dart';
import 'widgets/method_badge.dart';
import 'widgets/status_badge.dart';

/// Full-screen HTTP inspector — lists all recorded transactions.
///
/// Can be pushed directly:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const TapakInspectorScreen(),
/// ));
/// ```
class TapakInspectorScreen extends StatefulWidget {
  const TapakInspectorScreen({super.key});

  @override
  State<TapakInspectorScreen> createState() => _TapakInspectorScreenState();
}

class _TapakInspectorScreenState extends State<TapakInspectorScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text('All recorded requests will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              TapakStore.instance.clear();
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
        title: const Text('Tapak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: _confirmClear,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter by URL or method…',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: TapakStore.instance,
        builder: (context, _) {
          final all = TapakStore.instance.transactions;
          final items = _query.isEmpty
              ? all
              : all.where((t) {
                  return t.uri.toString().toLowerCase().contains(_query) ||
                      t.method.toLowerCase().contains(_query);
                }).toList();

          if (items.isEmpty) {
            return _EmptyState(hasTransactions: all.isNotEmpty);
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _TransactionTile(
              tx: items[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TapakDetailScreen(transaction: items[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasTransactions});
  final bool hasTransactions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasTransactions ? Icons.search_off : Icons.network_check,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(76),
          ),
          const SizedBox(height: 16),
          Text(
            hasTransactions ? 'No matches' : 'No requests yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.onTap});

  final HttpTransaction tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = tx.uri.path.isEmpty ? '/' : tx.uri.path;
    final host = '${tx.uri.host}${tx.uri.query.isNotEmpty ? '?…' : ''}';
    final t = tx.requestTime;
    final timeLabel =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            MethodBadge(tx.method),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: tx.status, statusCode: tx.statusCode),
                const SizedBox(height: 4),
                Text(
                  tx.duration != null
                      ? '${tx.durationText} · $timeLabel'
                      : timeLabel,
                  style: TextStyle(fontSize: 11, color: subtitleColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
