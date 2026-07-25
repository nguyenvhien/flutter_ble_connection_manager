import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_connection_manager/src/infrastructure/lifecycle_serializer.dart';

void main() {
  group('LifecycleSerializer', () {
    test('executes a single operation normally', () async {
      final serializer = LifecycleSerializer();
      var counter = 0;

      await serializer.run(() async {
        counter++;
      });

      expect(counter, 1);
    });

    test('serializes concurrent operations', () async {
      final serializer = LifecycleSerializer();
      final executionOrder = <String>[];

      final future1 = serializer.run(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        executionOrder.add('first');
      });

      final future2 = serializer.run(() async {
        executionOrder.add('second');
      });

      await Future.wait([future1, future2]);

      expect(executionOrder, ['first', 'second']);
    });

    test('propagates errors without blocking subsequent operations', () async {
      final serializer = LifecycleSerializer();

      await expectLater(
        serializer.run(() async => throw Exception('fail')),
        throwsException,
      );

      // Next operation should still work
      var counter = 0;
      await serializer.run(() async => counter++);
      expect(counter, 1);
    });

    test('runDeduped returns same future for same key', () async {
      final serializer = LifecycleSerializer();

      final future1 = serializer.runDeduped('connect', () async {
        await Future.delayed(const Duration(milliseconds: 50));
      });

      final future2 = serializer.runDeduped('connect', () async {
        // This should NOT execute
      });

      expect(identical(future1, future2), true);
      await Future.wait([future1, future2]);
    });

    test('runDeduped allows new operation after previous completes', () async {
      final serializer = LifecycleSerializer();
      var callCount = 0;

      await serializer.runDeduped('connect', () async {
        callCount++;
      });

      await serializer.runDeduped('connect', () async {
        callCount++;
      });

      expect(callCount, 2);
    });

    test('different keys run independently', () async {
      final serializer = LifecycleSerializer();

      final future1 = serializer.runDeduped('connect', () async {
        await Future.delayed(const Duration(milliseconds: 50));
      });

      // Different key — should NOT deduplicate
      final future2 = serializer.runDeduped('disconnect', () async {});

      expect(identical(future1, future2), false);
      await Future.wait([future1, future2]);
    });
  });
}
