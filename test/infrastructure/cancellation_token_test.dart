import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

void main() {
  group('CancellationToken', () {
    test('is not cancelled initially', () {
      final token = CancellationToken();
      expect(token.isCancelled, false);
    });

    test('isCancelled returns true after cancel()', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, true);
    });

    test('cancel() is idempotent', () {
      final token = CancellationToken();
      token.cancel();
      token.cancel(); // should not throw
      expect(token.isCancelled, true);
    });

    test('throwIfCancelled does nothing when not cancelled', () {
      final token = CancellationToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });

    test('throwIfCancelled throws CancelledException when cancelled', () {
      final token = CancellationToken();
      token.cancel();
      expect(
        () => token.throwIfCancelled(),
        throwsA(isA<CancelledException>()),
      );
    });
  });

  group('CancelledException', () {
    test('toString contains useful message', () {
      const ex = CancelledException();
      expect(ex.toString(), contains('cancelled'));
    });
  });
}
