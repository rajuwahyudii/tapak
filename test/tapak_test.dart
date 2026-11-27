import 'dart:ui' show Color;
import 'dart:convert';


import 'package:flutter_test/flutter_test.dart';
import 'package:tapak/tapak.dart';

// ---------------------------------------------------------------------------
// Top-level helpers
// ---------------------------------------------------------------------------

HttpTransaction _tx(
  String id, {
  String method = 'GET',
  Map<String, String>? query,
}) {
  final uri = Uri(
    scheme: 'https',
    host: 'example.com',
    path: '/api/$id',
    queryParameters: query,
  );
  return HttpTransaction(
    id: id,
    method: method,
    uri: uri,
    requestHeaders: {},
    requestTime: DateTime.now(),
  );
}

TapakLogEntry _logEntry(String id, TapakLogLevel level) => TapakLogEntry(
      id: id,
      title: 'title_$id',
      message: 'msg_$id',
      level: level,
      time: DateTime.now(),
    );

/// Full singleton reset — always call in setUp so tests are isolated.
void _fullReset() {
  TapakStore.instance
    ..clear()
    ..clearLogs()
    ..showButton = true
    ..buttonColor = null
    ..inspectorThemeMode = TapakThemeMode.system
    ..maxTransactions = 200
    ..maxLogs = 500;
}

// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // TapakStore — transactions
  // =========================================================================
  group('TapakStore transactions', () {
    setUp(_fullReset);

    test('starts empty', () {
      expect(TapakStore.instance.transactions, isEmpty);
    });

    test('add stores transaction; newest-first ordering', () async {
      TapakStore.instance.add(_tx('a'));
      TapakStore.instance.add(_tx('b'));
      await Future.microtask(() {});
      expect(TapakStore.instance.transactions.first.id, 'b');
      expect(TapakStore.instance.transactions.last.id, 'a');
    });

    test('clear removes all transactions', () {
      TapakStore.instance.add(_tx('a'));
      TapakStore.instance.clear();
      expect(TapakStore.instance.transactions, isEmpty);
    });

    test('findById returns correct transaction', () async {
      TapakStore.instance.add(_tx('x'));
      await Future.microtask(() {});
      expect(TapakStore.instance.findById('x')?.id, 'x');
    });

    test('findById returns null for missing id', () {
      expect(TapakStore.instance.findById('missing'), isNull);
    });

    test('respects maxTransactions cap', () async {
      TapakStore.instance.maxTransactions = 3;
      for (var i = 0; i < 5; i++) {
        TapakStore.instance.add(_tx('$i'));
      }
      await Future.microtask(() {});
      expect(TapakStore.instance.transactions.length, 3);
    });

    test('transactions list is unmodifiable', () async {
      TapakStore.instance.add(_tx('a'));
      await Future.microtask(() {});
      expect(
        () => TapakStore.instance.transactions.add(_tx('b')),
        throwsUnsupportedError,
      );
    });

    test('update invalidates the cache', () async {
      final tx = _tx('a');
      TapakStore.instance.add(tx);
      await Future.microtask(() {});

      // Capture the first list instance (cache is populated on access).
      final firstList = TapakStore.instance.transactions;
      tx.statusCode = 200;
      TapakStore.instance.update(tx); // sets _cachedTransactions = null
      await Future.microtask(() {});

      // A new access rebuilds the list — must NOT be the same object.
      expect(identical(firstList, TapakStore.instance.transactions), isFalse);
    });

    test('add notifies listeners (after microtask)', () async {
      var notified = 0;
      void listener() => notified++;
      TapakStore.instance.addListener(listener);
      TapakStore.instance.add(_tx('a'));
      await Future.microtask(() {});
      TapakStore.instance.removeListener(listener);
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('update notifies listeners (after microtask)', () async {
      final tx = _tx('a');
      TapakStore.instance.add(tx);
      await Future.microtask(() {});

      var notified = 0;
      void listener() => notified++;
      TapakStore.instance.addListener(listener);
      TapakStore.instance.update(tx);
      await Future.microtask(() {});
      TapakStore.instance.removeListener(listener);
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('clear notifies listeners immediately (no microtask needed)', () {
      TapakStore.instance.add(_tx('a'));

      var notified = 0;
      void listener() => notified++;
      TapakStore.instance.addListener(listener);
      TapakStore.instance.clear();
      TapakStore.instance.removeListener(listener);
      expect(notified, 1);
    });
  });

  // =========================================================================
  // TapakStore — logs
  // =========================================================================
  group('TapakStore logs', () {
    setUp(_fullReset);

    test('addLog stores entry; newest-first ordering', () async {
      TapakStore.instance.addLog(_logEntry('1', TapakLogLevel.debug));
      TapakStore.instance.addLog(_logEntry('2', TapakLogLevel.info));
      await Future.microtask(() {});
      expect(TapakStore.instance.logs.first.id, '2');
      expect(TapakStore.instance.logs.last.id, '1');
    });

    test('clearLogs empties the list', () async {
      TapakStore.instance.addLog(_logEntry('1', TapakLogLevel.debug));
      await Future.microtask(() {});
      TapakStore.instance.clearLogs();
      expect(TapakStore.instance.logs, isEmpty);
    });

    test('respects maxLogs cap', () async {
      TapakStore.instance.maxLogs = 3;
      for (var i = 0; i < 5; i++) {
        TapakStore.instance.addLog(_logEntry('$i', TapakLogLevel.info));
      }
      await Future.microtask(() {});
      expect(TapakStore.instance.logs.length, 3);
    });

    test('logs list is unmodifiable', () async {
      TapakStore.instance.addLog(_logEntry('1', TapakLogLevel.debug));
      await Future.microtask(() {});
      expect(
        () => TapakStore.instance.logs.add(_logEntry('x', TapakLogLevel.info)),
        throwsUnsupportedError,
      );
    });
  });

  // =========================================================================
  // TapakStore — settings
  // =========================================================================
  group('TapakStore settings', () {
    setUp(_fullReset);

    test('showButton toggles and notifies immediately', () {
      var notified = 0;
      void listener() => notified++;
      TapakStore.instance.addListener(listener);

      TapakStore.instance.showButton = false;
      expect(TapakStore.instance.showButton, isFalse);
      expect(notified, 1);

      TapakStore.instance.showButton = true;
      expect(TapakStore.instance.showButton, isTrue);
      expect(notified, 2);

      // Setting the same value must NOT notify.
      TapakStore.instance.showButton = true;
      expect(notified, 2);

      TapakStore.instance.removeListener(listener);
    });

    test('buttonColor set and null, notifies immediately', () {
      var notified = 0;
      void listener() => notified++;
      TapakStore.instance.addListener(listener);

      TapakStore.instance.buttonColor = const Color(0xFF00FF00);
      expect(TapakStore.instance.buttonColor, const Color(0xFF00FF00));
      expect(notified, 1);

      TapakStore.instance.buttonColor = null;
      expect(TapakStore.instance.buttonColor, isNull);
      expect(notified, 2);

      // Setting the same value must NOT notify.
      TapakStore.instance.buttonColor = null;
      expect(notified, 2);

      TapakStore.instance.removeListener(listener);
    });

    test('inspectorThemeMode cycles through all ThemeMode values', () {
      var notified = 0;
      void listener() => notified++;
      TapakStore.instance.addListener(listener);

      TapakStore.instance.inspectorThemeMode = TapakThemeMode.light;
      expect(TapakStore.instance.inspectorThemeMode, TapakThemeMode.light);
      expect(notified, 1);

      TapakStore.instance.inspectorThemeMode = TapakThemeMode.dark;
      expect(TapakStore.instance.inspectorThemeMode, TapakThemeMode.dark);
      expect(notified, 2);

      TapakStore.instance.inspectorThemeMode = TapakThemeMode.system;
      expect(TapakStore.instance.inspectorThemeMode, TapakThemeMode.system);
      expect(notified, 3);

      // Setting the same value must NOT notify.
      TapakStore.instance.inspectorThemeMode = TapakThemeMode.system;
      expect(notified, 3);

      TapakStore.instance.removeListener(listener);
    });
  });

  // =========================================================================
  // HttpTransaction
  // =========================================================================
  group('HttpTransaction', () {
    test('duration is null while pending, durationText is dash', () {
      final tx = _tx('a');
      expect(tx.duration, isNull);
      expect(tx.durationText, '—');
    });

    test('duration computed after responseTime is set', () {
      final tx = _tx('a');
      tx.responseTime = tx.requestTime.add(const Duration(milliseconds: 150));
      expect(tx.duration?.inMilliseconds, 150);
      expect(tx.durationText, '150ms');
    });

    test('durationText uses seconds format for >= 1000ms', () {
      final tx = _tx('a');
      tx.responseTime = tx.requestTime.add(const Duration(milliseconds: 2500));
      expect(tx.durationText, '2.5s');
    });

    test('formattedResponseBody pretty-prints JSON string (contains newlines)',
        () {
      final tx = _tx('a');
      tx.responseBody = '{"key":"value"}';
      expect(tx.formattedResponseBody, contains('\n'));
      expect(tx.formattedResponseBody, contains('"key"'));
      expect(tx.formattedResponseBody, contains('"value"'));
    });

    test('formattedResponseBody handles Map body', () {
      final tx = _tx('a');
      tx.responseBody = {'foo': 'bar'};
      expect(tx.formattedResponseBody, contains('"foo"'));
      expect(tx.formattedResponseBody, contains('"bar"'));
      expect(tx.formattedResponseBody, contains('\n'));
    });

    test('formattedResponseBody decodes List<int> UTF-8 byte array', () {
      final tx = _tx('a');
      tx.responseBody = utf8.encode('{"bytes":true}');
      expect(tx.formattedResponseBody, contains('"bytes"'));
      expect(tx.formattedResponseBody, contains('\n'));
    });

    test('formattedResponseBody returns plain text for non-JSON string', () {
      final tx = _tx('a');
      tx.responseBody = 'plain text response';
      expect(tx.formattedResponseBody, 'plain text response');
    });

    test('formattedResponseBody returns empty string for null body', () {
      final tx = _tx('a');
      expect(tx.formattedResponseBody, '');
    });

    test('formattedRequestBody returns empty string for null requestBody', () {
      // _tx() leaves requestBody null.
      expect(_tx('a').formattedRequestBody, '');
    });

    test('isReplayed defaults to false', () {
      expect(_tx('a').isReplayed, isFalse);
    });

    // ponytail: formattedResponseBody is cached on first access.
    // Mutating responseBody AFTER first access does NOT update the cached
    // result — this is intentional; responseBody is set once before display.
    test(
        'formattedResponseBody is cached; mutation after first access is ignored',
        () {
      final tx = _tx('a');
      tx.responseBody = '{"v":1}';
      final first = tx.formattedResponseBody; // populates _cachedResponseBody
      tx.responseBody = '{"v":99}'; // mutate — cache is NOT invalidated
      // identical() confirms the exact same String object is returned.
      expect(identical(tx.formattedResponseBody, first), isTrue);
    });
  });

  // =========================================================================
  // HarExporter
  // =========================================================================
  group('HarExporter', () {
    /// Builds a completed transaction suitable for HAR export tests.
    HttpTransaction completedTx({
      String id = '1',
      String method = 'GET',
      String url = 'https://example.com/api/test',
      int statusCode = 200,
      dynamic responseBody,
    }) {
      final tx = HttpTransaction(
        id: id,
        method: method,
        uri: Uri.parse(url),
        requestHeaders: {'Accept': 'application/json'},
        requestTime: DateTime.parse('2024-01-15T10:30:00.000Z'),
      );
      tx.statusCode = statusCode;
      tx.responseHeaders = {'content-type': 'application/json'};
      tx.responseBody = responseBody ?? {'result': 'ok'};
      tx.responseTime = DateTime.parse('2024-01-15T10:30:00.150Z');
      tx.status = TransactionStatus.success;
      return tx;
    }

    test('toHarMap returns correct top-level structure', () {
      final har = HarExporter.toHarMap([]);
      final log = har['log'] as Map;
      expect(log['version'], '1.2');
      expect((log['creator'] as Map)['name'], 'tapak');
      expect(log['entries'], isA<List>());
    });

    test('entries list length matches transaction count', () {
      final har = HarExporter.toHarMap([
        completedTx(id: '1'),
        completedTx(id: '2'),
      ]);
      expect(((har['log'] as Map)['entries'] as List).length, 2);
    });

    test('entry startedDateTime uses requestTime as ISO-8601', () {
      final tx = completedTx();
      final har = HarExporter.toHarMap([tx]);
      final entry = ((har['log'] as Map)['entries'] as List).first as Map;
      expect(entry['startedDateTime'], tx.requestTime.toIso8601String());
    });

    test('request method is uppercased', () {
      final tx = completedTx(method: 'post');
      final har = HarExporter.toHarMap([tx]);
      final entry = ((har['log'] as Map)['entries'] as List).first as Map;
      expect((entry['request'] as Map)['method'], 'POST');
    });

    test('request url includes query string', () {
      final tx = completedTx(url: 'https://example.com/api?foo=bar&baz=1');
      final har = HarExporter.toHarMap([tx]);
      final entry = ((har['log'] as Map)['entries'] as List).first as Map;
      final url = (entry['request'] as Map)['url'] as String;
      expect(url, contains('foo=bar'));
    });

    test('request queryString list maps uri.queryParameters', () {
      final tx = completedTx(url: 'https://example.com/api?foo=bar&baz=1');
      final har = HarExporter.toHarMap([tx]);
      final entry = ((har['log'] as Map)['entries'] as List).first as Map;
      final qs = (entry['request'] as Map)['queryString'] as List;
      expect(qs.length, 2);
      final names = qs.map((e) => (e as Map)['name'] as String).toSet();
      expect(names, containsAll(['foo', 'baz']));
    });

    test('response status and statusText are populated', () {
      final tx = completedTx(statusCode: 200);
      final har = HarExporter.toHarMap([tx]);
      final entry = ((har['log'] as Map)['entries'] as List).first as Map;
      final response = entry['response'] as Map;
      expect(response['status'], 200);
      expect(response['statusText'], 'OK');
    });

    test('response content.text is compact JSON — no newlines', () {
      final tx = completedTx(responseBody: {'result': 'ok'});
      final har = HarExporter.toHarMap([tx]);
      final entry = ((har['log'] as Map)['entries'] as List).first as Map;
      final content = (entry['response'] as Map)['content'] as Map;
      final text = content['text'] as String;
      // HAR uses _rawBodyText (jsonEncode), NOT formattedResponseBody (pretty).
      expect(text, isNot(contains('\n')));
      expect((jsonDecode(text) as Map)['result'], 'ok');
    });

    test('pending transaction response has status 0', () {
      final pendingTx = _tx('pending'); // no statusCode set
      final har = HarExporter.toHarMap([pendingTx]);
      final entry = ((har['log'] as Map)['entries'] as List).first as Map;
      expect((entry['response'] as Map)['status'], 0);
    });

    test('toHarString produces valid, parseable JSON', () {
      final str = HarExporter.toHarString([completedTx()]);
      expect(() => jsonDecode(str), returnsNormally);
      final decoded = jsonDecode(str) as Map;
      expect(decoded['log'], isA<Map>());
    });
  });

  // =========================================================================
  // TapakLogLevel
  // =========================================================================
  group('TapakLogLevel', () {
    test('all levels have non-null color', () {
      for (final level in TapakLogLevel.values) {
        expect(level.color, isNotNull, reason: '${level.name}.color is null');
      }
    });

    test('all levels have distinct labels', () {
      final labels = TapakLogLevel.values.map((l) => l.label).toList();
      expect(labels.toSet().length, TapakLogLevel.values.length);
    });

    test('all levels have distinct icons', () {
      final icons = TapakLogLevel.values.map((l) => l.icon).toList();
      expect(icons.toSet().length, TapakLogLevel.values.length);
    });

    test('all levels have non-empty ANSI escape strings', () {
      for (final level in TapakLogLevel.values) {
        expect(level.ansi, isNotEmpty, reason: '${level.name}.ansi is empty');
        expect(level.ansi, startsWith('\x1B['),
            reason: '${level.name}.ansi does not start with ESC[');
      }
    });
  });

  // =========================================================================
  // TapakLog
  // =========================================================================
  group('TapakLog', () {
    setUp(_fullReset);

    Future<TapakLogEntry> firstEntry() async {
      await Future.microtask(() {});
      return TapakStore.instance.logs.first;
    }

    test('debug records entry with correct level/title/message', () async {
      TapakLog.debug('src', 'the message');
      final entry = await firstEntry();
      expect(entry.level, TapakLogLevel.debug);
      expect(entry.title, 'src');
      expect(entry.message, 'the message');
    });

    test('info records entry with correct level', () async {
      TapakLog.info('src', 'msg');
      expect((await firstEntry()).level, TapakLogLevel.info);
    });

    test('success records entry with correct level', () async {
      TapakLog.success('src', 'msg');
      expect((await firstEntry()).level, TapakLogLevel.success);
    });

    test('warning records entry with correct level', () async {
      TapakLog.warning('src', 'msg');
      expect((await firstEntry()).level, TapakLogLevel.warning);
    });

    test('danger records entry with correct level', () async {
      TapakLog.danger('src', 'msg');
      expect((await firstEntry()).level, TapakLogLevel.danger);
    });

    test('entries are newest-first in store', () async {
      TapakLog.debug('a', 'first');
      TapakLog.info('b', 'second');
      await Future.microtask(() {});
      expect(TapakStore.instance.logs.first.title, 'b');
      expect(TapakStore.instance.logs.last.title, 'a');
    });

    test('never throws for empty string inputs', () {
      expect(() => TapakLog.debug('', ''), returnsNormally);
    });

    test('never throws for very long string inputs', () {
      final long = 'x' * 10000;
      expect(() => TapakLog.warning(long, long), returnsNormally);
    });
  });

  // =========================================================================
  // TapakReplayer
  // =========================================================================
  group('TapakReplayer', () {
    setUp(_fullReset);

    test('creates replayed transaction in store before HTTP completes',
        () async {
      final original = HttpTransaction(
        id: 'orig',
        method: 'GET',
        uri: Uri.parse('https://example.com/api/test'),
        requestHeaders: {},
        requestTime: DateTime.now(),
      );

      // Fire replay without awaiting. Everything up to the first `await _send`
      // inside replay() runs synchronously: add(tx) + tx.isReplayed = true.
      // The network call will fail (no connectivity in tests), but the internal
      // try/catch means the returned Future completes normally anyway.
      // ignore: unawaited_futures
      TapakReplayer.replay(original).catchError((_) => original);

      await Future.microtask(() {});

      expect(TapakStore.instance.transactions, isNotEmpty);
      final replayed = TapakStore.instance.transactions.first;
      expect(replayed.isReplayed, isTrue);
      expect(replayed.method, original.method);
      expect(replayed.uri, original.uri);
    });
  });
}
