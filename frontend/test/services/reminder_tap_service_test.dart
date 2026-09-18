import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/reminder_tap_service.dart';

void main() {
  Map<String, dynamic> tap(String message, String id) => {
    'type': 'ROUTINE_REMINDER', 'sourceId': id, 'messageId': message,
  };

  test('a running app is notified and only the latest pending tap is kept', () {
    final service = ReminderTapService();
    var updates = 0;
    service.addListener(() => updates++);
    service.receive(tap('first', '1'));
    final oldGeneration = service.generation;
    service.receive(tap('second', '2'));
    expect(updates, 2);
    expect(service.generation, greaterThan(oldGeneration));
    expect(service.take()?.route, '/routine/2');
    expect(service.take(), isNull);
  });

  test('duplicate delivery cannot navigate twice but a later reminder can', () {
    final service = ReminderTapService();
    service.receive(tap('first', '1'));
    service.take();
    service.receive(tap('first', '1'));
    expect(service.pending, isNull);
    service.receive(tap('next-day', '1'));
    expect(service.take()?.sourceId, '1');
  });

  test('sign out clears pending click and invalidates in-flight navigation', () {
    final service = ReminderTapService();
    service.receive(tap('first', '1'));
    final generation = service.generation;
    service.reset();
    expect(service.pending, isNull);
    expect(service.generation, isNot(generation));
  });

  test('untrusted route and malformed identifiers cannot choose a destination', () {
    expect(ReminderTap.parse({'type': 'OTHER', 'sourceId': '1', 'route': '/admin'}), isNull);
    expect(ReminderTap.parse(tap('bad', '../auth')), isNull);
    expect(ReminderTap.parse(tap('zero', '0')), isNull);
    final valid = ReminderTap.parse({
      'type': 'CARE_SCHEDULE_REMINDER', 'sourceId': '42', 'route': '/admin',
    });
    expect(valid?.route, '/routine/schedule/42');
  });
}
