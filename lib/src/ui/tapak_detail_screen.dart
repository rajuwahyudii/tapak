// ignore_for_file: deprecated_library_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../har/har_exporter.dart';
import '../model/http_transaction.dart';
import '../replay/tapak_replayer.dart';
import 'widgets/method_badge.dart';
import 'widgets/status_badge.dart';
import 'widgets/body_viewer.dart';

enum _DetailAction { replay, exportHar }

/// Detail screen for a single [HttpTransaction].
///
/// Shows three tabs: Overview, Request, Response (plus Error when applicable).
class TapakDetailScreen extends StatefulWidget {
  const TapakDetailScreen({super.key, required this.transaction});

  final HttpTransaction transaction;

  @override
  State<TapakDetailScreen> createState() => _TapakDetailScreenState();
}

class _TapakDetailScreenState extends State<TapakDetailScreen> {
  bool _replaying = false;

  Future<void> _replay() async {
    if (_replaying) return;
    setState(() => _replaying = true);
    try {
      final newTx = await TapakReplayer.replay(widget.transaction);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Replayed — ${newTx.statusCode ?? 'error'}'),
          action: SnackBarAction(
            label: 'View in list',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }

  Future<void> _exportHar() async {
    final har = HarExporter.toHarString([widget.transaction]);
    await Clipboard.setData(ClipboardData(text: har));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('HAR copied to clipboard.')),
      );
    }
  }

  void _onMenuSelected(_DetailAction action) {
    switch (action) {
      case _DetailAction.replay:
        _replay();
      case _DetailAction.exportHar:
        _exportHar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final path = tx.uri.path.isEmpty ? '/' : tx.uri.path;
    final hasError = tx.status == TransactionStatus.error;
    final isPending = tx.status == TransactionStatus.pending;

    return DefaultTabController(
      length: hasError ? 4 : 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              MethodBadge(tx.method),
              if (tx.isReplayed) ...[
                const SizedBox(width: 6),
                _ReplayChip(),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          actions: [
            // Spinner shown while replay is in progress.
            if (_replaying)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            PopupMenuButton<_DetailAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onSelected: _onMenuSelected,
              itemBuilder: (_) => [
                if (!isPending)
                  PopupMenuItem(
                    value: _DetailAction.replay,
                    enabled: !_replaying,
                    child: const _DetailMenuItem(
                      icon: Icons.replay,
                      label: 'Replay request',
                    ),
                  ),
                const PopupMenuItem(
                  value: _DetailAction.exportHar,
                  child: _DetailMenuItem(
                    icon: Icons.download_outlined,
                    label: 'Export as HAR',
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Overview'),
              const Tab(text: 'Request'),
              const Tab(text: 'Response'),
              if (hasError) const Tab(text: 'Error'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(tx: tx),
            _RequestTab(tx: tx),
            _ResponseTab(tx: tx),
            if (hasError) _ErrorTab(tx: tx),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview tab
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.tx});
  final HttpTransaction tx;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoRow('URL', tx.uri.toString()),
        _InfoRow('Method', tx.method),
        _InfoRow(
          'Status',
          tx.statusCode?.toString() ??
              (tx.status == TransactionStatus.pending ? 'Pending…' : 'Error'),
          trailing: StatusBadge(status: tx.status, statusCode: tx.statusCode),
        ),
        _InfoRow('Duration', tx.durationText),
        _InfoRow('Started', _formatTime(tx.requestTime)),
        if (tx.responseTime != null)
          _InfoRow('Completed', _formatTime(tx.responseTime!)),
      ],
    );
  }

  static String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${_p(l.month)}-${_p(l.day)} '
        '${_p(l.hour)}:${_p(l.minute)}:${_p(l.second)}.${l.millisecond.toString().padLeft(3, '0')}';
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}

// ---------------------------------------------------------------------------
// Request tab
// ---------------------------------------------------------------------------

class _RequestTab extends StatelessWidget {
  const _RequestTab({required this.tx});
  final HttpTransaction tx;

  @override
  Widget build(BuildContext context) {
    final queryParams = tx.uri.queryParameters;
    final allHeaders = <String, String>{
      ...tx.requestHeaders.map((k, v) => MapEntry(k, v.toString())),
      // Show response headers here since user wants headers in Request tab
      if (tx.responseHeaders != null)
        ...tx.responseHeaders!.map((k, v) => MapEntry(k, v.toString())),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Headers section
        _SectionTitle('Headers (${allHeaders.length})'),
        if (allHeaders.isEmpty)
          const _EmptyHint('No headers')
        else
          ...allHeaders.entries.map((e) => _KeyValueRow(e.key, e.value)),

        const SizedBox(height: 20),

        // Query parameters section
        _SectionTitle('Query Parameters'),
        if (queryParams.isEmpty)
          const _EmptyHint('No query parameters')
        else
          ...queryParams.entries.map((e) => _KeyValueRow(e.key, e.value)),

        // Body section (only if has request body, e.g. POST)
        if (tx.formattedRequestBody.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle('Body'),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: BodyViewer(body: tx.formattedRequestBody),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Response tab
// ---------------------------------------------------------------------------

class _ResponseTab extends StatelessWidget {
  const _ResponseTab({required this.tx});
  final HttpTransaction tx;

  @override
  Widget build(BuildContext context) {
    final isPending = tx.status == TransactionStatus.pending;
    final body = isPending ? '' : tx.formattedResponseBody;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _SectionTitle('Body'),
        ),
        Expanded(
          child: isPending
              ? const Center(child: _EmptyHint('Waiting for response…'))
              : body.isEmpty
                  ? const Center(child: _EmptyHint('Empty body'))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: BodyViewer(body: body),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error tab
// ---------------------------------------------------------------------------

class _ErrorTab extends StatelessWidget {
  const _ErrorTab({required this.tx});
  final HttpTransaction tx;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF44336).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF44336).withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFF44336), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF44336),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                tx.error ?? 'Unknown error',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: trailing != null
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  )
                : SelectableText(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.key_, this.value);
  final String key_;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key_: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DetailMenuItem extends StatelessWidget {
  const _DetailMenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

class _ReplayChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.withAlpha(120), width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.replay, size: 9, color: Colors.orange.shade700),
          const SizedBox(width: 3),
          Text(
            'replay',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
