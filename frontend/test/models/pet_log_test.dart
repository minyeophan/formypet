import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet_log.dart';

void main() {
  test(
    'PetLog parses ordered photo dimensions and the idempotent applied version',
    () {
      final log = PetLog.fromJson({
        'id': 8,
        'petId': 3,
        'date': '2026-10-11',
        'time': '09:15:00',
        'note': '산책',
        'version': 2,
        'appliedVersion': 1,
        'photos': [
          {
            'id': 91,
            'url': '/api/v1/media/91',
            'position': 0,
            'width': 1200,
            'height': 800,
          },
        ],
      });

      expect(log.id, '8');
      expect(log.cover?.id, '91');
      expect(log.cover?.width, 1200);
      expect(log.appliedVersion, 1);
      expect(log.version, greaterThan(log.appliedVersion!));
    },
  );

  test('PetLogPage parses cursor and available timeline years', () {
    final page = PetLogPage.fromJson({
      'items': [],
      'nextCursor': 'MjAyNi0xMC0xMVQwOToxNToxMHw4',
      'years': [2026, 2025],
      'hasAny': true,
    });

    expect(page.items, isEmpty);
    expect(page.nextCursor, isNotNull);
    expect(page.years, [2026, 2025]);
    expect(page.hasAny, isTrue);
  });
}
