import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('post notification marks read and opens the post', (tester) async {
    final service = _FakeNotificationService(
      NotificationFeed(
        items: [
          NotificationItem(
            id: '2',
            type: 'POST_LIKE',
            postId: '9',
            title: '좋아요 알림',
            body: '게시글에 좋아요가 있어요',
          ),
        ],
        hasMore: false,
        unreadCount: 1,
      ),
    );
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationScreen(),
        ),
        GoRoute(
          path: '/community/posts/:postId',
          builder: (_, state) => Scaffold(
            body: Text('post:${state.pathParameters['postId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationServiceProvider.overrideWithValue(service)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('게시글에 좋아요가 있어요'));
    await tester.pumpAndSettle();

    expect(service.markReadCalls, ['2']);
    expect(find.text('post:9'), findsOneWidget);
  });

  testWidgets('notification with no target stays on the list safely', (tester) async {
    final service = _FakeNotificationService(
      NotificationFeed(
        items: [
          NotificationItem(
            id: '3',
            type: 'POST_LIKE',
            title: '대상을 찾을 수 없는 알림',
            body: '이동할 대상이 없어요',
          ),
        ],
        hasMore: false,
        unreadCount: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이동할 대상이 없어요'));
    await tester.pumpAndSettle();

    expect(find.text('이동할 대상이 없어요'), findsOneWidget);
    expect(service.markReadCalls, ['3']);
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
