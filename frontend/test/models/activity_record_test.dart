import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/activity_record.dart';

void main() {
  test('ActivityRecord parses nullable fields and detail', () {
    final record = ActivityRecord.fromJson({
      'id': 7,
      'petId': 3,
      'typeId': 'water',
      'date': '2026-08-28',
      'time': null,
      'routineId': null,
      'note': null,
      'mediaUrls': ['https://example.test/a.jpg'],
      'detail': {'amount': 250.0},
    });

    expect(record.id, '7');
    expect(record.time, isNull);
    expect(record.routineId, isNull);
    expect(record.mediaUrls, ['https://example.test/a.jpg']);
    expect(record.detail['amount'], 250.0);
  });

  test('ActivityRecord toJson excludes response-only fields', () {
    const record = ActivityRecord(
      id: '7',
      petId: '3',
      typeId: 'water',
      date: '2026-08-28',
      detail: {'amount': 250},
    );

    expect(record.toJson(), {
      'typeId': 'water',
      'date': '2026-08-28',
      'detail': {'amount': 250},
    });
  });
}
