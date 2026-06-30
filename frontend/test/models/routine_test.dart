import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/routine.dart';

void main() {
  test('Routine keeps label and defaults monthly interval to one', () {
    final routine = Routine.fromJson({
      'id': 1,
      'petId': 2,
      'label': '심장약',
      'typeId': 'medicine',
      'repeatType': 'daily',
      'times': ['08:00'],
      'days': <int>[],
      'startDate': '2026-06-01',
    });

    expect(routine.label, '심장약');
    expect(routine.monthlyInterval, 1);
    expect(routine.toJson(), {
      'label': '심장약',
      'typeId': 'medicine',
      'repeatType': 'daily',
      'times': ['08:00'],
      'days': <int>[],
      'startDate': '2026-06-01',
      'monthlyInterval': 1,
    });
  });

  test('Routine keeps explicit monthly interval', () {
    final routine = Routine.fromJson({
      'id': 1,
      'petId': 2,
      'label': '정기 검진',
      'typeId': 'checkup',
      'repeatType': 'monthly',
      'times': ['09:30'],
      'days': <int>[],
      'startDate': '2026-06-01',
      'monthlyInterval': 3,
    });

    expect(routine.monthlyInterval, 3);
  });
}
