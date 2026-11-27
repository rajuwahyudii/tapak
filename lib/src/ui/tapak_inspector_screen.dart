// ignore_for_file: deprecated_library_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../har/har_exporter.dart';
import '../model/http_transaction.dart';
import '../store/tapak_store.dart';
import 'tapak_detail_screen.dart';
import 'tapak_logs_screen.dart';
import '../replay/tapak_replayer.dart';
import 'widgets/method_badge.dart';
import 'widgets/status_badge.dart';

enum _MenuAction {
  exportHar,
  clear,
  themeLight,
  themeDark,
  themeSystem,
  viewLogs,
  qaTools,
}

/// Full-screen HTTP inspector — lists all recorded transactions.
///
/// Can be pushed directly:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const TapakInspectorScreen(),
/// ));
/// ```
///
/// [onClose] is provided automatically when opened via [TapakOverlay].
class TapakInspectorScreen extends StatefulWidget {
  const TapakInspectorScreen({super.key, this.onClose});

  /// Called when the user taps the close button.
  /// Only needed when the screen is shown as an overlay (not via Navigator.push).
  final VoidCallback? onClose;

  @override
  State<TapakInspectorScreen> createState() => _TapakInspectorScreenState();
}

class _TapakInspectorScreenState extends State<TapakInspectorScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (_searchVisible) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _searchFocus.requestFocus(),
        );
      } else {
        _searchController.clear();
        _query = '';
      }
    });
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

  void _exportHar() {
    final transactions = TapakStore.instance.transactions;
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No requests to export.')),
      );
      return;
    }
    final har = HarExporter.toHarString(transactions);
    Clipboard.setData(ClipboardData(text: har));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'HAR copied (${transactions.length} '
          'request${transactions.length == 1 ? '' : 's'}).',
        ),
      ),
    );
  }

  Future<void> _showReplaySheet(HttpTransaction tx) async {
    final shouldReplay = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => _ReplaySheet(tx: tx),
    );
    if (shouldReplay != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Replaying…'),
        duration: Duration(seconds: 60),
      ),
    );

    final newTx = await TapakReplayer.replay(tx);
    messenger.hideCurrentSnackBar();

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Replayed — ${newTx.statusCode ?? 'error'}'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TapakDetailScreen(transaction: newTx),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _onMenuSelected(_MenuAction action) {
    switch (action) {
      case _MenuAction.exportHar:
        _exportHar();
      case _MenuAction.clear:
        _confirmClear();
      case _MenuAction.themeLight:
        TapakStore.instance.inspectorThemeMode = TapakThemeMode.light;
      case _MenuAction.themeDark:
        TapakStore.instance.inspectorThemeMode = TapakThemeMode.dark;
      case _MenuAction.themeSystem:
        TapakStore.instance.inspectorThemeMode = TapakThemeMode.system;
      case _MenuAction.viewLogs:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TapakLogsScreen()),
        );
      case _MenuAction.qaTools:
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: false,
          isScrollControlled: true,
          builder: (_) => const _QAToolsSheet(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tapak Inspector'),
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: widget.onClose,
              )
            : null,
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            tooltip: _searchVisible ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          // More menu
          ListenableBuilder(
            listenable: TapakStore.instance,
            builder: (context, _) {
              final mode = TapakStore.instance.inspectorThemeMode;
              return PopupMenuButton<_MenuAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More',
                onSelected: _onMenuSelected,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _MenuAction.themeLight,
                    child: _MenuItem(
                      icon: Icons.light_mode_outlined,
                      label: 'Light mode',
                      checked: mode == TapakThemeMode.light,
                    ),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.themeDark,
                    child: _MenuItem(
                      icon: Icons.dark_mode_outlined,
                      label: 'Dark mode',
                      checked: mode == TapakThemeMode.dark,
                    ),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.themeSystem,
                    child: _MenuItem(
                      icon: Icons.brightness_auto_outlined,
                      label: 'System default',
                      checked: mode == TapakThemeMode.system,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _MenuAction.viewLogs,
                    child: _MenuItem(
                      icon: Icons.terminal,
                      label: 'View logs',
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _MenuAction.qaTools,
                    child: ListenableBuilder(
                      listenable: TapakStore.instance,
                      builder: (context, _) => _MenuItem(
                        icon: Icons.science_outlined,
                        label: 'QA Tools',
                        active: TapakStore.instance.simulatedDate != null,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _MenuAction.exportHar,
                    child: _MenuItem(
                      icon: Icons.download_outlined,
                      label: 'Export as HAR',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _MenuAction.clear,
                    child: _MenuItem(
                      icon: Icons.delete_outline,
                      label: 'Clear logs',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        // Search bar — only shown when toggled on.
        bottom: _searchVisible
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'Filter by URL or method…',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _query = '';
                              }),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
              )
            : null,
      ),
      body: ListenableBuilder(
        listenable: TapakStore.instance,
        builder: (context, _) {
          final all = TapakStore.instance.transactions;
          final items = _query.isEmpty
              ? all
              : all
                  .where(
                    (t) =>
                        t.uri.toString().toLowerCase().contains(_query) ||
                        t.method.toLowerCase().contains(_query),
                  )
                  .toList();

          final sim = TapakStore.instance.simulatedDate;

          Widget list;
          if (items.isEmpty) {
            list = _EmptyState(hasTransactions: all.isNotEmpty);
          } else {
            list = ListView.separated(
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
                onLongPress: items[i].status != TransactionStatus.pending
                    ? () => _showReplaySheet(items[i])
                    : null,
              ),
            );
          }

          if (sim == null) return list;

          return Column(
            children: [
              _SimulatedDateBanner(date: sim),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MenuItem extends StatelessWidget {
  const _MenuItem(
      {required this.icon,
      required this.label,
      this.checked = false,
      this.active = false});

  final IconData icon;
  final String label;
  final bool checked;

  /// Shows a small coloured dot — used to indicate a QA feature is active.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 20),
            if (active)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        if (checked)
          Icon(Icons.check,
              size: 16, color: Theme.of(context).colorScheme.primary),
      ],
    );
  }
}

class _ReplayBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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

// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.onTap,
    this.onLongPress,
  });

  final HttpTransaction tx;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

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
      onLongPress: onLongPress,
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
                  Row(
                    children: [
                      if (tx.isReplayed) ...[
                        _ReplayBadge(),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                      ),
                    ],
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

// ---------------------------------------------------------------------------

class _ReplaySheet extends StatelessWidget {
  const _ReplaySheet({required this.tx});
  final HttpTransaction tx;

  @override
  Widget build(BuildContext context) {
    final path = tx.uri.path.isEmpty ? '/' : tx.uri.path;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — request info
            Row(
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
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        tx.uri.host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Replay action
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.replay),
                label: const Text('Replay request'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QA Tools
// ---------------------------------------------------------------------------

class _SimulatedDateBanner extends StatelessWidget {
  const _SimulatedDateBanner({required this.date});
  final DateTime date;

  static String _label(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}'
        ', ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final amber = Colors.amber.shade800;
    return ColoredBox(
      color: Colors.amber.withAlpha(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.science_outlined, size: 15, color: amber),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Simulated date: ${_label(date)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: amber,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => TapakStore.instance.simulatedDate = null,
              child: Icon(Icons.close, size: 15, color: amber),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _QAToolsSheet extends StatefulWidget {
  const _QAToolsSheet();

  @override
  State<_QAToolsSheet> createState() => _QAToolsSheetState();
}

class _QAToolsSheetState extends State<_QAToolsSheet> {
  Future<void> _pickDate() async {
    final store = TapakStore.instance;
    final initial = store.simulatedDate ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;

    store.simulatedDate = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? initial.hour,
      time?.minute ?? initial.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TapakStore.instance,
      builder: (context, _) {
        final sim = TapakStore.instance.simulatedDate;
        final cfg = TapakStore.instance.simulatedDateConfig;
        final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

        // Describe the injection method so QA knows what to expect server-side.
        final injectionParts = <String>[];
        if (cfg.headerName != null)
          injectionParts.add('header: ${cfg.headerName}');
        if (cfg.queryParamName != null)
          injectionParts.add('param: ${cfg.queryParamName}');
        final injectionLabel = injectionParts.isEmpty
            ? 'No injection configured'
            : injectionParts.join(' · ');

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'QA Tools',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section: Simulated Date
                Text(
                  'Simulated Date',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Device clock stays unchanged. '
                  'The chosen date is forwarded to the server on every request.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                ),
                const SizedBox(height: 12),

                // Current value chip
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: sim == null
                      ? Text(
                          'Not set — requests use real server time',
                          style: TextStyle(fontSize: 13, color: subtitleColor),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _SimulatedDateBanner._label(sim),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sent as: ${cfg.formatDate(sim)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: subtitleColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  injectionLabel,
                  style: TextStyle(fontSize: 11, color: subtitleColor),
                ),

                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon:
                            const Icon(Icons.calendar_today_outlined, size: 16),
                        label: Text(sim == null ? 'Set date & time' : 'Change'),
                        onPressed: _pickDate,
                      ),
                    ),
                    if (sim != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () =>
                            TapakStore.instance.simulatedDate = null,
                        child: const Text('Clear'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
