import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/care_schedule.dart';

void main() {
  test('CareSchedule request JSON omits identity and createdAt fields', () {
    const schedule = CareSchedule(
      id: '17',
      petId: '3',
      categoryId: 'hospital',
      title: 'Checkup',
      startDate: '2026-08-28',
      startTime: '09:00',
      endDate: '2026-08-28',
      endTime: '10:00',
      allDay: false,
      place: 'Clinic',
      memo: null,
      reminder: '1 hour before',
      createdAt: '2026-08-01T00:00:00',
    );

    expect(schedule.toRequestJson(), isNot(contains('id')));
    expect(schedule.toRequestJson(), isNot(contains('petId')));
    expect(schedule.toRequestJson(), isNot(contains('createdAt')));
    expect(schedule.toRequestJson()['reminder'], '1 hour before');
  });

  test('CareSchedule parses all-day schedules without times', () {
    final schedule = CareSchedule.fromJson({
      'id': 17,
      'petId': 3,
      'categoryId': 'vaccination',
      'title': 'Vaccine',
      'startDate': '2026-08-28',
      'startTime': null,
      'endDate': '2026-08-28',
      'endTime': null,
      'allDay': true,
      'place': null,
      'memo': null,
      'reminder': '알림 없음',
      'createdAt': '2026-08-01T00:00:00',
    });

    expect(schedule.id, '17');
    expect(schedule.allDay, isTrue);
    expect(schedule.startTime, isNull);
    expect(schedule.endTime, isNull);
  });
}
