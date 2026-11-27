// ignore_for_file: deprecated_library_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scrollable body viewer with syntax highlighting and search.
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

  // Determine once whether body is valid JSON.
  // ponytail: skip full jsonDecode — just check first non-whitespace char.
  bool _isJson = false;

  @override
  void initState() {
    super.initState();
    _checkJson();
  }

  @override
  void didUpdateWidget(BodyViewer old) {
    super.didUpdateWidget(old);
    if (old.body != widget.body) _checkJson();
  }

  void _checkJson() {
    final trimmed = widget.body.trimLeft();
    _isJson = trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _search(String query) => setState(() {
        _query = query.toLowerCase();
        _currentMatch = 0;
      });

  void _jumpToMatch(int index) {
    if (_matchKeys.isEmpty || index < 0 || index >= _matchKeys.length) return;
    setState(() => _currentMatch = index);
    final ctx = _matchKeys[index].currentContext;
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
    _jumpToMatch((_currentMatch + 1) % _matchKeys.length);
  }

  void _prevMatch() {
    if (_matchKeys.isEmpty) return;
    _jumpToMatch((_currentMatch - 1 + _matchKeys.length) % _matchKeys.length);
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

    // Truncate large bodies for display — full copy still available via button.
    const maxDisplay = 8000;
    final displayBody = widget.body.length > maxDisplay
        ? '${widget.body.substring(0, maxDisplay)}\n\n... (truncated, ${widget.body.length} chars total — use copy button for full body)'
        : widget.body;

    // Count matches for the search bar counter.
    int matchCount = 0;
    if (_query.isNotEmpty) {
      final lower = displayBody.toLowerCase();
      var i = 0;
      while (true) {
        i = lower.indexOf(_query, i);
        if (i == -1) break;
        matchCount++;
        i += _query.length;
      }
    }

    // Build content widget.
    final newMatchKeys = <GlobalKey>[];
    Widget content;
    if (_query.isNotEmpty) {
      content = _HighlightedText(
        text: displayBody,
        query: _query,
        matchKeys: newMatchKeys,
        currentMatch: _currentMatch,
      );
    } else if (_isJson) {
      content = _SyntaxHighlightedJson(json: displayBody);
    } else {
      content = Text(
        displayBody,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
        ),
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
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  onPressed: matchCount > 0 ? _nextMatch : null,
                  tooltip: 'Next',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),
        ),
        // Body content
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

// ---------------------------------------------------------------------------
// Syntax-highlighted JSON renderer.
// ponytail: regex on large text freezes UI. Skip highlighting for >10KB.
// ---------------------------------------------------------------------------

class _SyntaxHighlightedJson extends StatelessWidget {
  const _SyntaxHighlightedJson({required this.json});

  final String json;

  static const _maxHighlight = 10000; // chars - skip highlighting above this

  @override
  Widget build(BuildContext context) {
    // For large JSON, just show plain monospace text — no highlighting.
    if (json.length > _maxHighlight) {
      return Text(
        json,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFD4D4D4)
              : const Color(0xFF333333),
        ),
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;

    final keyC = dark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
    final strC = dark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    final numC = dark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    final kwC = dark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
    final plainC = dark ? const Color(0xFFD4D4D4) : const Color(0xFF333333);

    // Groups: 1+2 = key string + colon, 3 = string value,
    //         4 = number, 5 = keyword (true/false/null), 6 = bracket/punct.
    final re = RegExp(
      r'("(?:[^"\]|\.)*")(\s*:)'
      r'|("(?:[^"\]|\.)*")'
      r'|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)'
      r'|(true|false|null)'
      r'|([{}\[\],:])',
    );

    final spans = <TextSpan>[];
    int last = 0;

    for (final m in re.allMatches(json)) {
      if (m.start > last) {
        spans.add(TextSpan(text: json.substring(last, m.start)));
      }

      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: TextStyle(color: keyC)));
        spans.add(TextSpan(text: m.group(2), style: TextStyle(color: plainC)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: m.group(3), style: TextStyle(color: strC)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(text: m.group(4), style: TextStyle(color: numC)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(text: m.group(5), style: TextStyle(color: kwC)));
      } else {
        spans.add(TextSpan(text: m.group(6), style: TextStyle(color: plainC)));
      }

      last = m.end;
    }

    if (last < json.length) {
      spans.add(TextSpan(text: json.substring(last)));
    }

    return Text.rich(
      TextSpan(
        children: spans,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
          color: plainC,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plain-text viewer with search highlighting.
// ---------------------------------------------------------------------------

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
      return Text(
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

    return Text.rich(
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
