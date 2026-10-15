// Synthetic local QA data and isolated Android package only. Keep --no-uninstall.
// QA backend: scheduler enabled, interval 1000ms, timezone Asia/Seoul, no FCM credentials.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/notification_settings_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/routine_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'notification feed, scheduler, preferences and persisted read state',
    (tester) async {
      expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
      expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
      final directory = (await getExternalStorageDirectory())!;
      expect(directory.path, contains('com.formypet.frontend.mediatest/'));
      initApiClient('http://127.0.0.1:18083');
      final fixture = File('${directory.path}/notification-migration.json');
      const existing = bool.fromEnvironment('VERIFY_EXISTING_NOTIFICATION');
      final service = NotificationService();
      Map<String, dynamic> saved = {};
      Dio? actor;
      if (!existing) {
        final owner = await AuthService().register(
          email:
              'notification-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
          password: _password(),
          nickname: 'JPA 알림 검증',
        );
        final pet = await PetService().createPet({
          'name': '알림 검증',
          'species': 'dog',
        });
        saved = {'userId': owner.id, 'petId': pet.id};
        actor = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:18083'));
        addTearDown(actor.close);
        final tokens =
            unwrap(
                  await actor.post(
                    '/api/v1/auth/register',
                    data: {
                      'email':
                          'notification-actor-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
                      'password': _password(),
                      'nickname': '알림 작성자',
                    },
                  ),
                )
                as Map<String, dynamic>;
        actor.options.headers['Authorization'] =
            'Bearer ${tokens['accessToken']}';
        final profile =
            unwrap(await actor.get('/api/v1/users/me')) as Map<String, dynamic>;
        saved['actorId'] = profile['id'].toString();
        final post = await CommunityService().createPost(
          title: '알림 검증 게시글',
          content: '격리 QA 본문',
          category: 'FREE',
        );
        for (var i = 0; i < 3; i++) {
          await actor.post(
            '/api/v1/posts/${post.id}/comments',
            data: {'content': '알림 댓글 $i'},
          );
        }
        await actor.post('/api/v1/posts/${post.id}/like');
        expect((await service.list()).items, hasLength(4));
        final first = await service.list(limit: 2);
        expect(first.hasMore, isTrue);
        final next = await service.list(cursor: first.nextCursor, limit: 2);
        expect(next.hasMore, isFalse);
        expect({
          ...first.items.map((n) => n.id),
          ...next.items.map((n) => n.id),
        }, hasLength(4));
        saved['socialIds'] = (await service.list()).items
            .map((n) => n.id)
            .toList();
        await expectLater(
          actor.patch('/api/v1/notifications/${first.items.first.id}/read'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'foreign notification',
              404,
            ),
          ),
        );
        await dio.post(
          '/api/v1/notifications/device-tokens',
          data: {'token': 'qa-notification-${owner.id}', 'platform': 'ANDROID'},
        );
        await dio.delete(
          '/api/v1/notifications/device-tokens',
          queryParameters: {'token': 'qa-notification-${owner.id}'},
        );
      } else {
        saved =
            jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
        expect((await AuthService().getProfile()).id, saved['userId']);
        expect(await service.getSettings(), isFalse);
        final feed = await service.list();
        expect(feed.unreadCount, 0);
        expect(
          feed.items.map((n) => n.id).toSet(),
          (saved['ids'] as List).cast<String>().toSet(),
        );
        expect(feed.items.every((n) => n.isRead), isTrue);
        expect(
          feed.items
              .singleWhere((n) => n.id == saved['firstReadId'])
              .readAt!
              .toIso8601String(),
          saved['firstReadAt'],
        );
      }

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FormypetApp(),
        ),
      );
      await _until(
        tester,
        () =>
            !container.read(authProvider).isLoading &&
            !container.read(petProvider).isLoading,
      );
      expect(container.read(authProvider).isAuthenticated, isTrue);
      final router = container.read(routerProvider);
      router.go('/my/settings/notifications');
      await _until(
        tester,
        () =>
            find.byType(Switch).evaluate().isNotEmpty &&
            !container.read(notificationSettingsProvider).loading,
      );

      if (!existing) {
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        await _tap(tester, find.byType(Switch));
        await _until(
          tester,
          () => !container.read(notificationSettingsProvider).saving,
        );
        expect(await service.getSettings(), isFalse);
        final due = DateTime.now()
            .toUtc()
            .add(const Duration(hours: 9))
            .subtract(const Duration(minutes: 1));
        final date = due.toIso8601String().substring(0, 10);
        final routine = await RoutineService().createRoutine(
          saved['petId'] as String,
          {
            'label': 'JPA 예약 루틴',
            'typeId': 'water',
            'repeatType': 'daily',
            'days': [],
            'monthlyInterval': 1,
            'startDate': date,
            'times': [_time(due)],
            'notificationEnabled': true,
          },
        );
        final careStart = due.add(const Duration(hours: 1));
        final careDate = careStart.toIso8601String().substring(0, 10);
        final care =
            unwrap(
                  await dio.post(
                    '/api/v1/pets/${saved['petId']}/care-schedules',
                    data: {
                      'categoryId': 'hospital',
                      'title': 'JPA 예약 케어',
                      'startDate': careDate,
                      'endDate': careDate,
                      'startTime': _time(careStart),
                      'endTime': _time(
                        careStart.add(const Duration(minutes: 10)),
                      ),
                      'allDay': false,
                      'reminder': '1시간 전',
                    },
                  ),
                )
                as Map<String, dynamic>;
        saved['routineId'] = routine.id;
        saved['careId'] = care['id'].toString();
        await _pause(tester, 4);
        expect(
          (await service.list()).items.where((n) => n.sourceId != null),
          isEmpty,
        );
        await _tap(tester, find.byType(Switch));
        await _until(
          tester,
          () => !container.read(notificationSettingsProvider).saving,
        );
        expect(await service.getSettings(), isTrue);
        await _eventually(
          tester,
          () async =>
              (await service.list()).items
                  .where((n) => n.sourceId != null)
                  .length ==
              2,
        );
        final reminders = (await service.list()).items
            .where((n) => n.sourceId != null)
            .toList();
        expect(reminders.map((n) => n.type).toSet(), {
          'ROUTINE_REMINDER',
          'CARE_SCHEDULE_REMINDER',
        });
        for (final reminder in reminders) {
          expect(reminder.actorUserId, isNull);
          expect(reminder.scheduledFor!.hour, due.hour);
          expect(reminder.scheduledFor!.minute, due.minute);
          expect(
            DateTime.now()
                .toUtc()
                .difference(reminder.createdAt!.toUtc())
                .abs(),
            lessThan(const Duration(minutes: 1)),
          );
        }
        await _pause(tester, 3);
        expect(
          (await service.list()).items.where((n) => n.sourceId != null),
          hasLength(2),
        );
      } else {
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      }

      router.go('/notifications');
      await _until(
        tester,
        () =>
            container.read(notificationProvider).hasLoaded &&
            !container.read(notificationProvider).isLoading,
      );
      expect(find.text('루틴 알림'), findsOneWidget);
      expect(find.text('케어 일정 알림'), findsOneWidget);
      if (!existing) {
        final feed = await service.list();
        expect(feed.items, hasLength(6));
        final first = feed.items.first;
        await _tap(tester, find.byKey(Key('notification-row-${first.id}')));
        await _eventually(
          tester,
          () async => (await service.list()).items
              .singleWhere((n) => n.id == first.id)
              .isRead,
        );
        final read = (await service.list()).items.singleWhere(
          (n) => n.id == first.id,
        );
        expect(
          DateTime.now().toUtc().difference(read.readAt!.toUtc()).abs(),
          lessThan(const Duration(minutes: 1)),
        );
        saved['firstReadId'] = read.id;
        saved['firstReadAt'] = read.readAt!.toIso8601String();
        await service.markRead(read.id);
        expect(
          (await service.list()).items
              .singleWhere((n) => n.id == read.id)
              .readAt,
          read.readAt,
        );
        router.go('/notifications');
        await _until(tester, () => find.text('모두 읽음').evaluate().isNotEmpty);
        await _tap(tester, find.text('모두 읽음'));
        await _eventually(
          tester,
          () async => (await service.list()).unreadCount == 0,
        );
        await dio.put('/api/v1/users/me/blocks/${saved['actorId']}');
        expect((await service.list()).items, hasLength(2));
        await expectLater(
          service.markRead((saved['socialIds'] as List).first as String),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'hidden notification',
              404,
            ),
          ),
        );
        await dio.delete('/api/v1/users/me/blocks/${saved['actorId']}');
        expect((await service.list()).items, hasLength(6));
        router.go('/my/settings/notifications');
        await _until(
          tester,
          () =>
              find.byType(Switch).evaluate().isNotEmpty &&
              !container.read(notificationSettingsProvider).loading,
        );
        await _tap(tester, find.byType(Switch));
        await _until(
          tester,
          () => !container.read(notificationSettingsProvider).saving,
        );
        expect(await service.getSettings(), isFalse);
        final finalFeed = await service.list();
        expect(finalFeed.unreadCount, 0);
        saved['ids'] = finalFeed.items.map((n) => n.id).toList();
        await fixture.writeAsString(jsonEncode(saved));
      }
      expect(tester.takeException(), isNull);
      debugPrint(
        existing
            ? 'NOTIFICATION_RESTART_VERIFIED'
            : 'NOTIFICATION_FULL_VERIFIED',
      );
    },
  );
}

String _password() => List.generate(
  32,
  (_) => Random.secure().nextInt(16).toRadixString(16),
).join();
String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
Future<void> _pause(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 2; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
  }
}

Future<void> _eventually(
  WidgetTester tester,
  Future<bool> Function() ready,
) async {
  for (var i = 0; i < 60; i++) {
    if (await ready()) return;
    await _pause(tester, 1);
  }
  fail('Notification API state did not become ready');
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Notification UI did not become ready');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
