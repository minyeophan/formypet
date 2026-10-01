import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/notification.dart';

void main() {
  test('parses nullable social fields for scheduled notifications', () {
    final notification = NotificationItem.fromJson({
      'id': 7,
      'actorUserId': null,
      'actorNickname': null,
      'type': 'ROUTINE_REMINDER',
      'postId': null,
      'commentId': null,
      'sourceType': 'ROUTINE',
      'sourceId': 12,
      'scheduledFor': '2026-08-27T09:00:00',
      'title': '루틴 알림',
      'body': '산책할 시간이에요',
      'readAt': null,
      'createdAt': '2026-08-27T08:00:00',
    });

    expect(notification.id, '7');
    expect(notification.actorNickname, isNull);
    expect(notification.postId, isNull);
    expect(notification.isRead, isFalse);
    expect(notification.type, 'ROUTINE_REMINDER');
  });
}
