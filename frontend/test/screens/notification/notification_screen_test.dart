import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/notification.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/screens/notification/notification_screen.dart';
import 'package:frontend/services/notification_service.dart';

void main() {
  testWidgets('notification screen renders unread notification and read action',
      (tester) async {
    final service = _FakeNotificationService(
      NotificationFeed(
        items: [
          NotificationItem(
            id: '1',
            type: 'ROUTINE_REMINDER',
            title: '루틴 알림',
            body: '산책할 시간이에요',
          ),
        ],
        hasMore: false,
        unreadCount: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('루틴 알림'), findsOneWidget);
    expect(find.text('산책할 시간이에요'), findsOneWidget);
    await tester.tap(find.text('산책할 시간이에요'));
    await tester.pumpAndSettle();
    expect(service.markReadCalls, ['1']);
  });
}

class _FakeNotificationService extends NotificationService {
  final NotificationFeed feed;
  final markReadCalls = <String>[];

  _FakeNotificationService(this.feed);

  @override
  Future<NotificationFeed> list({String? cursor, int limit = 20}) async => feed;

  @override
  Future<void> markRead(String id) async => markReadCalls.add(id);
}
