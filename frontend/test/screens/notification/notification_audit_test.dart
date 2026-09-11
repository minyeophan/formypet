import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/screens/notification/notification_screen.dart';
import 'package:frontend/screens/pet/pet_detail_screen.dart';
import 'package:frontend/services/care_schedule_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../support/audit_api.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final ids in <List<String>>[
    [],
    ['1'],
  ]) {
    testWidgets('pull to refresh works with ${ids.length} notifications', (
      tester,
    ) async {
      var refreshed = false;
      useAuditApi(AuditApi((r) => auditFeed(refreshed ? ['new'] : ids)));
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: NotificationScreen())),
      );
      await tester.pumpAndSettle();
      refreshed = true;
      await tester.dragFrom(const Offset(300, 200), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(find.text('내용 new'), findsOneWidget);
    });
  }

  testWidgets('refresh failure preserves list and offers visible retry', (
    tester,
  ) async {
    var fail = false;
    useAuditApi(
      AuditApi((r) {
        if (fail) throw Exception('offline');
        return auditFeed(['1']);
      }),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    fail = true;
    await tester.runAsync(() async {
      try {
        await container.read(notificationProvider.notifier).loadFirstPage();
      } catch (_) {}
    });
    await tester.pumpAndSettle();
    expect(find.text('내용 1'), findsOneWidget);
    expect(find.text('알림을 불러오지 못했어요.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('알림을 불러오지 못했어요.'), findsNothing);
  });

  testWidgets('read all failure is handled and can be retried', (tester) async {
    var fail = true;
    useAuditApi(
      AuditApi((r) {
        if (r.path.endsWith('/read-all') && fail) throw Exception('offline');
        return r.method == 'GET' ? auditFeed(['1']) : null;
      }),
    );
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NotificationScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('모두 읽음 처리하지 못했어요'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    fail = false;
    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();
    expect(find.byType(CircleAvatar), findsNothing);
  });

  for (final schedule in [false, true]) {
    testWidgets(
      '${schedule ? 'schedule' : 'routine'} reminder opens exact target owned by another pet',
      (tester) async {
        final targetPath = schedule
            ? '/routine/schedule/target'
            : '/routine/target';
        final pet = PetNotifier.testWithServices(
          _pets,
          scheduleService: CareScheduleService(),
        );
        useAuditApi(
          AuditApi((r) {
            if (r.path == '/api/v1/notifications') {
              return {
                'items': [
                  {
                    ...auditNotification('1'),
                    'type': schedule
                        ? 'CARE_SCHEDULE_REMINDER'
                        : 'ROUTINE_REMINDER',
                    'sourceId': 'target',
                    'sourceType': schedule ? 'CARE_SCHEDULE' : 'ROUTINE',
                  },
                ],
                'unreadCount': 1,
                'hasMore': false,
              };
            }
            if (r.path ==
                '/api/v1/pets/b/${schedule ? 'care-schedules' : 'routines'}') {
              return [
                schedule
                    ? {
                        'id': 'target',
                        'petId': 'b',
                        'categoryId': 'hospital',
                        'title': '병원',
                        'startDate': '2026-09-08',
                        'endDate': '2026-09-08',
                        'allDay': true,
                        'createdAt': '2026-09-01',
                      }
                    : {
                        'id': 'target',
                        'petId': 'b',
                        'typeId': 'walk',
                        'label': '산책',
                        'repeatType': 'daily',
                        'times': ['09:00'],
                        'days': [],
                        'startDate': '2026-09-01',
                      },
              ];
            }
            return auditDefaultResponse(r);
          }),
        );
        final router = GoRouter(
          initialLocation: '/notifications',
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, _) => const NotificationScreen(),
            ),
            GoRoute(
              path: '/routine',
              builder: (_, _) => const Scaffold(body: Text('wrong-list')),
            ),
            GoRoute(
              path: targetPath,
              builder: (_, _) =>
                  Scaffold(body: Text('target:${pet.state.activePetId}')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [petProvider.overrideWith((_) => pet)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('내용 1'));
        await tester.pumpAndSettle();
        expect(find.text('target:b'), findsOneWidget);
        expect(
          schedule
              ? pet.state.schedules.single.id
              : pet.state.routines.single.id,
          'target',
        );
      },
    );
  }

  testWidgets(
    'pet delete shows pending state and failure feedback without navigating away',
    (tester) async {
      final pending = Completer<Object?>();
      final api = AuditApi(
        (r) => r.method == 'DELETE' ? pending.future : auditDefaultResponse(r),
      );
      useAuditApi(api);
      final pet = PetNotifier.testWithServices(_pets);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [petProvider.overrideWith((_) => pet)],
          child: const MaterialApp(home: PetDetailScreen(petId: 'a')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('삭제'));
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '삭제'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final showedPending = find.text('삭제 중...').evaluate().isNotEmpty;
      pending.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(showedPending, isTrue);
      expect(find.textContaining('삭제하지 못했어요'), findsOneWidget);
      expect(pet.state.pets.map((p) => p.id), ['a', 'b']);
      expect(find.text('삭제'), findsOneWidget);
    },
  );

  testWidgets('a notification tap awaiting read cannot navigate after logout', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    useAuditApi(
      AuditApi((r) => r.method == 'PATCH' ? pending.future : auditFeed(['1'])),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationScreen(),
        ),
        GoRoute(
          path: '/community/posts/9',
          builder: (_, _) => const Scaffold(body: Text('old-account-post')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('내용 1'));
    await tester.pump();
    container
        .read(notificationProvider.notifier)
        .resetSession(authenticated: false);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('old-account-post'), findsNothing);
    expect(find.text('새로운 알림이 없어요.'), findsOneWidget);
  });

  testWidgets('home offers retry after initial pet list failure', (
    tester,
  ) async {
    var fail = true;
    useAuditApi(
      AuditApi((r) {
        if (r.path == '/api/v1/pets' && fail) throw Exception('offline');
        if (r.path == '/api/v1/posts') {
          return {'items': [], 'hasMore': false};
        }
        return auditDefaultResponse(r);
      }),
    );
    final pet = PetNotifier.testWithServices(_pets);
    await tester.runAsync(() async {
      try {
        await pet.loadForAuthenticatedUser();
      } catch (_) {}
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petProvider.overrideWith((_) => pet),
          authProvider.overrideWith(
            (_) => AuthNotifier.test(
              const AuthState(isLoading: false, isAuthenticated: true),
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('반려동물을 먼저 등록해 주세요'), findsNothing);
    fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(pet.state.activePetId, 'a');
    expect(find.text('다시 시도'), findsNothing);
  });
}

final _pets = PetState(
  isLoading: false,
  hasOnboarded: true,
  pets: [Pet.fromJson(auditPet('a')), Pet.fromJson(auditPet('b'))],
  activePetId: 'a',
  records: const [],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);
