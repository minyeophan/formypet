import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/pet_log_temp_file_registry.dart';

void main() {
  test(
    'retains files whose first cleanup fails and retries them later',
    () async {
      final registry = PetLogTempFileRegistry();
      registry.register('/tmp/export.mp4');
      var attempts = 0;

      await registry.cleanup((_) async {
        attempts++;
        return attempts > 1;
      });
      await registry.cleanup((_) async {
        attempts++;
        return attempts > 1;
      });

      expect(attempts, 2);
      expect(registry.pendingPaths, isEmpty);
    },
  );

  test('can delete failed attempt inputs while retaining its result', () async {
    final registry = PetLogTempFileRegistry();
    registry.register('/tmp/source.jpg');
    registry.register('/tmp/result.mp4');
    final deleted = <String>[];
    await registry.cleanupExcept({'/tmp/result.mp4'}, (path) async {
      deleted.add(path);
      return true;
    });

    expect(deleted, ['/tmp/source.jpg']);
    expect(registry.pendingPaths, {'/tmp/result.mp4'});
  });
}
