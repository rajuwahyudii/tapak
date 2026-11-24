import 'package:flutter/material.dart';

import '../model/http_transaction.dart';
import 'widgets/method_badge.dart';
import 'widgets/status_badge.dart';
import 'widgets/body_viewer.dart';

/// Detail screen for a single [HttpTransaction].
///
/// Shows three tabs: Overview, Request, Response.
class TapakDetailScreen extends StatelessWidget {
  const TapakDetailScreen({super.key, required this.transaction});

  final HttpTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final path = tx.uri.path.isEmpty ? '/' : tx.uri.path;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              MethodBadge(tx.method),
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Request'),
              Tab(text: 'Response'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(tx: tx),
            _RequestTab(tx: tx),
            _ResponseTab(tx: tx),
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
        _InfoRow('Sent at', _formatTime(tx.requestTime)),
        if (tx.responseTime != null)
          _InfoRow('Received at', _formatTime(tx.responseTime!)),
        if (tx.error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(message: tx.error!),
        ],
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF44336).withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF44336).withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Error',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFF44336),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(message, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

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

// ---------------------------------------------------------------------------
// Request tab
// ---------------------------------------------------------------------------

class _RequestTab extends StatelessWidget {
  const _RequestTab({required this.tx});
  final HttpTransaction tx;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Headers'),
        SizedBox(height: 180, child: _HeadersView(headers: tx.requestHeaders)),
        const Divider(height: 1),
        _SectionLabel('Body'),
        Expanded(child: BodyViewer(body: tx.formattedRequestBody)),
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
    final body = tx.status == TransactionStatus.pending
        ? ''
        : tx.formattedResponseBody;

    final emptyLabel = tx.status == TransactionStatus.pending
        ? 'Waiting for response…'
        : 'Empty body';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Headers'),
        SizedBox(
          height: 180,
          child: _HeadersView(headers: tx.responseHeaders ?? {}),
        ),
        const Divider(height: 1),
        _SectionLabel('Body'),
        Expanded(
          child: BodyViewer(body: body, emptyLabel: emptyLabel),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _HeadersView extends StatelessWidget {
  const _HeadersView({required this.headers});
  final Map<String, dynamic> headers;

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return Center(
        child: Text(
          'No headers',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: headers.length,
      itemBuilder: (context, i) {
        final entry = headers.entries.elementAt(i);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  entry.value.toString(),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
