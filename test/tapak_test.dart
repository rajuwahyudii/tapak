import 'package:flutter_test/flutter_test.dart';
import 'package:tapak/tapak.dart';

void main() {
  group('TapakStore', () {
    setUp(() => TapakStore.instance.clear());

    test('starts empty', () {
      expect(TapakStore.instance.transactions, isEmpty);
    });

    test('add stores transaction; newest-first ordering', () {
      TapakStore.instance.add(_tx('a'));
      TapakStore.instance.add(_tx('b'));

      expect(TapakStore.instance.transactions.first.id, 'b');
      expect(TapakStore.instance.transactions.last.id, 'a');
    });

    test('clear removes all transactions', () {
      TapakStore.instance.add(_tx('a'));
      TapakStore.instance.clear();
      expect(TapakStore.instance.transactions, isEmpty);
    });

    test('findById returns correct transaction or null', () {
      TapakStore.instance.add(_tx('x'));
      expect(TapakStore.instance.findById('x')?.id, 'x');
      expect(TapakStore.instance.findById('missing'), isNull);
    });

    test('respects maxTransactions cap', () {
      TapakStore.instance.maxTransactions = 3;
      for (var i = 0; i < 5; i++) {
        TapakStore.instance.add(_tx('$i'));
      }
      expect(TapakStore.instance.transactions.length, 3);
      TapakStore.instance.maxTransactions = 200; // reset
    });

    test('notifies listeners on add and clear', () {
      var notified = 0;
      TapakStore.instance.addListener(() => notified++);
      TapakStore.instance.add(_tx('a'));
      TapakStore.instance.clear();
      TapakStore.instance.removeListener(() {});
      expect(notified, 2);
    });
  });

  group('HttpTransaction', () {
    test('duration is null while pending', () {
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

    test('durationText uses seconds for >= 1000ms', () {
      final tx = _tx('a');
      tx.responseTime = tx.requestTime.add(const Duration(milliseconds: 2500));
      expect(tx.durationText, '2.5s');
    });

    test('formattedResponseBody pretty-prints a JSON string', () {
      final tx = _tx('a');
      tx.responseBody = '{"key":"value"}';
      expect(tx.formattedResponseBody, contains('\n'));
      expect(tx.formattedResponseBody, contains('"key"'));
    });

    test('formattedResponseBody handles non-JSON strings', () {
      final tx = _tx('a');
      tx.responseBody = 'plain text';
      expect(tx.formattedResponseBody, 'plain text');
    });

    test('formattedResponseBody handles Map body', () {
      final tx = _tx('a');
      tx.responseBody = {'foo': 'bar'};
      expect(tx.formattedResponseBody, contains('"foo"'));
    });

    test('formattedRequestBody returns empty string for null body', () {
      final tx = _tx('a');
      expect(tx.formattedRequestBody, '');
    });
  });
}

HttpTransaction _tx(String id) => HttpTransaction(
  id: id,
  method: 'GET',
  uri: Uri.parse('https://example.com/api/$id'),
  requestHeaders: {},
  requestTime: DateTime.now(),
);
