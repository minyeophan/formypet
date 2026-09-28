import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/account_deletion_cleanup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'failure does not skip other cleanup and survives a new instance',
    () async {
      final calls = <String>[];
      final first = AccountDeletionCleanup(
        actions: {
          'failure': (_) async {
            calls.add('failure');
            throw StateError('offline');
          },
          'credentials': (_) async {
            calls.add('credentials');
          },
        },
      );
      expect(await first.run('42'), isFalse);
      expect(calls, ['failure', 'credentials', 'failure']);
      final second = AccountDeletionCleanup(
        actions: {
          'retry': (id) async {
            calls.add(id);
          },
        },
      );
      expect(await second.retryPending(), isTrue);
      expect(calls.last, '42');
      expect(await second.retryPending(), isTrue);
      expect(calls.where((value) => value == '42'), hasLength(1));
    },
  );

  test(
    'retry waits for in-flight cleanup without running actions twice',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      var calls = 0;
      final cleanup = AccountDeletionCleanup(
        actions: {
          'one': (_) async {
            calls++;
            started.complete();
            await finish.future;
          },
        },
      );
      final deletion = cleanup.run('42');
      await started.future;
      final retry = cleanup.retryPending();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      finish.complete();
      expect(await deletion, isTrue);
      expect(await retry, isTrue);
      expect(calls, 1);
    },
  );
}
