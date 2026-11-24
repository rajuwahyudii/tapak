import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

/// Scrollable body viewer with beautiful JSON formatting and search.
class BodyViewer extends StatefulWidget {
  const BodyViewer({
    super.key,
    required this.body,
    this.emptyLabel = 'Empty body',
  });

  final String body;
  final String emptyLabel;

  @override
  State<BodyViewer> createState() => _BodyViewerState();
}

class _BodyViewerState extends State<BodyViewer> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<GlobalKey> _matchKeys = [];
  String _query = '';
  int _currentMatch = 0;
  int _matchCount = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _query = query.toLowerCase();
      _currentMatch = 0;
    });
  }

  void _jumpToMatch(int index) {
    if (_matchKeys.isEmpty || index < 0 || index >= _matchKeys.length) return;

    setState(() => _currentMatch = index);

    final key = _matchKeys[index];
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  void _nextMatch() {
    if (_matchKeys.isEmpty) return;
    final next = (_currentMatch + 1) % _matchKeys.length;
    _jumpToMatch(next);
  }

  void _prevMatch() {
    if (_matchKeys.isEmpty) return;
    final prev = (_currentMatch - 1 + _matchKeys.length) % _matchKeys.length;
    _jumpToMatch(prev);
  }

  int _countMatches() {
    if (_query.isEmpty) return 0;
    final lowerBody = widget.body.toLowerCase();
    var count = 0;
    var index = 0;
    while (true) {
      index = lowerBody.indexOf(_query, index);
      if (index == -1) break;
      count++;
      index += _query.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.body.isEmpty) {
      return Center(
        child: Text(
          widget.emptyLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    // Count matches first
    int matchCount = 0;
    if (_query.isNotEmpty) {
      final lowerBody = widget.body.toLowerCase();
      var index = 0;
      while (true) {
        index = lowerBody.indexOf(_query, index);
        if (index == -1) break;
        matchCount++;
        index += _query.length;
      }
    }

    // Check for empty JSON object/array
    final trimmed = widget.body.trim();
    if (trimmed == '{}' || trimmed == '[]') {
      return Center(
        child: Text(
          'Empty response',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    // Try to parse as JSON for pretty display
    final newMatchKeys = <GlobalKey>[];
    Widget content;
    try {
      final parsed = jsonDecode(widget.body);
      content = _JsonView(
        data: parsed,
        query: _query,
        matchKeys: newMatchKeys,
        currentMatch: _currentMatch,
      );
    } catch (_) {
      // Not JSON, show as plain text with search highlight
      content = _HighlightedText(
        text: widget.body,
        query: _query,
        matchKeys: newMatchKeys,
        currentMatch: _currentMatch,
      );
    }
    _matchKeys = newMatchKeys;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _search('');
                              },
                            )
                          : null,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: _search,
                  ),
                ),
              ),
              if (_query.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  matchCount == 0
                      ? '0 results'
                      : '${_currentMatch + 1} / $matchCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                  onPressed: matchCount > 0 ? _prevMatch : null,
                  tooltip: 'Previous',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  onPressed: matchCount > 0 ? _nextMatch : null,
                  tooltip: 'Next',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Content
        Expanded(
          child: Stack(
            children: [
              Scrollbar(
                thumbVisibility: true,
                interactive: true,
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 48, 12),
                  child: content,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy to clipboard',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.body));
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
          ),
        ),
      ],
    );
  }
}

/// Highlighted plain text with search matches
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.matchKeys,
    required this.currentMatch,
  });

  final String text;
  final String query;
  final List<GlobalKey> matchKeys;
  final int currentMatch;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return SelectableText(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
        ),
      );
    }

    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    var lastEnd = 0;
    var matchIndex = 0;

    while (true) {
      final start = lowerText.indexOf(query, lastEnd);
      if (start == -1) break;

      if (start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, start)));
      }

      final key = GlobalKey();
      matchKeys.add(key);
      final isCurrent = matchIndex == currentMatch;

      spans.add(
        WidgetSpan(
          child: Container(
            key: key,
            color: isCurrent ? Colors.orange : Colors.yellow.withAlpha(150),
            child: Text(
              text.substring(start, start + query.length),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isCurrent ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      );

      lastEnd = start + query.length;
      matchIndex++;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
}

/// Renders JSON data as a beautiful tree structure with search highlight
class _JsonView extends StatelessWidget {
  const _JsonView({
    required this.data,
    this.indent = 0,
    required this.query,
    required this.matchKeys,
    required this.currentMatch,
  });

  final dynamic data;
  final int indent;
  final String query;
  final List<GlobalKey> matchKeys;
  final int currentMatch;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data == null) {
      return _keyword('null', isDark);
    }
    if (data is bool) {
      return _keyword(data.toString(), isDark);
    }
    if (data is num) {
      return _highlightedText(data.toString(), isDark, isNumber: true);
    }
    if (data is String) {
      return _highlightedText('"$data"', isDark, isString: true);
    }
    if (data is List) {
      return _buildList(context, data, isDark);
    }
    if (data is Map) {
      return _buildMap(context, data, isDark);
    }
    return Text(data.toString());
  }

  Widget _highlightedText(
    String text,
    bool isDark, {
    bool isString = false,
    bool isNumber = false,
    bool isKey = false,
  }) {
    if (query.isEmpty || !text.toLowerCase().contains(query)) {
      Color color;
      if (isKey) {
        color = isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
      } else if (isString) {
        color = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
      } else if (isNumber) {
        color = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
      } else {
        color = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333);
      }
      return Text(
        text,
        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color),
      );
    }

    // Build highlighted spans
    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    var lastEnd = 0;

    Color baseColor;
    if (isKey) {
      baseColor = isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
    } else if (isString) {
      baseColor = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    } else if (isNumber) {
      baseColor = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    } else {
      baseColor = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333);
    }

    while (true) {
      final start = lowerText.indexOf(query, lastEnd);
      if (start == -1) break;

      if (start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, start),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: baseColor,
            ),
          ),
        );
      }

      final key = GlobalKey();
      matchKeys.add(key);
      final isCurrent = matchKeys.length - 1 == currentMatch;

      spans.add(
        WidgetSpan(
          child: Container(
            key: key,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.orange : Colors.yellow.withAlpha(180),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              text.substring(start, start + query.length),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isCurrent ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      );

      lastEnd = start + query.length;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: baseColor,
          ),
        ),
      );
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildList(BuildContext context, List list, bool isDark) {
    if (list.isEmpty) {
      return _bracket('[]', isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bracket('[', isDark),
        ...list.asMap().entries.map((entry) {
          final isLast = entry.key == list.length - 1;
          return Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: _JsonView(
                    data: entry.value,
                    indent: indent + 1,
                    query: query,
                    matchKeys: matchKeys,
                    currentMatch: currentMatch,
                  ),
                ),
                if (!isLast) _comma(isDark),
              ],
            ),
          );
        }),
        _bracket(']', isDark),
      ],
    );
  }

  Widget _buildMap(BuildContext context, Map map, bool isDark) {
    if (map.isEmpty) {
      return _bracket('{}', isDark);
    }

    final entries = map.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bracket('{', isDark),
        ...entries.asMap().entries.map((entry) {
          final key = entry.value.key.toString();
          final value = entry.value.value;
          final isLast = entry.key == entries.length - 1;

          return Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _highlightedText('"$key"', isDark, isKey: true),
                _colon(isDark),
                const SizedBox(width: 4),
                Flexible(
                  child: _JsonView(
                    data: value,
                    indent: indent + 1,
                    query: query,
                    matchKeys: matchKeys,
                    currentMatch: currentMatch,
                  ),
                ),
                if (!isLast) _comma(isDark),
              ],
            ),
          );
        }),
        _bracket('}', isDark),
      ],
    );
  }

  Widget _keyword(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF),
      ),
    );
  }

  Widget _bracket(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333),
      ),
    );
  }

  Widget _colon(bool isDark) {
    return Text(
      ':',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333),
      ),
    );
  }

  Widget _comma(bool isDark) {
    return Text(
      ',',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333),
      ),
    );
  }
}
