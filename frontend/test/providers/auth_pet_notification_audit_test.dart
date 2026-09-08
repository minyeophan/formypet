import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/secure_storage.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/care_schedule.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/care_schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/audit_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => initApiClient('http://example.test', includeAuthInterceptor: false),
  );
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'valid-access',
      'refresh_token': 'valid-refresh',
    });
    SharedPreferences.setMockInitialValues({});
    useAuditApi(AuditApi(auditDefaultResponse));
  });
  tearDown(() => setAuthExpiredHandler(null));

  test(
    'recoverable record load failure keeps validated login and credentials',
    () async {
      useAuditApi(
        AuditApi((r) {
          if (r.path.endsWith('/records')) throw Exception('offline');
          return auditDefaultResponse(r);
        }),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider);
      await until(() => !container.read(authProvider).isLoading);
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(await getAccessToken(), 'valid-access');
      expect(await getRefreshToken(), 'valid-refresh');
    },
  );

  test(
    'expired auth while pet bootstrap is pending cannot restore login',
    () async {
      final pending = Completer<Object?>();
      final api = AuditApi(
        (r) =>
            r.path == '/api/v1/pets' ? pending.future : auditDefaultResponse(r),
      );
      useAuditApi(api);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider);
      await until(() => api.requests.any((r) => r.path == '/api/v1/pets'));
      await notifyAuthExpired();
      pending.complete([auditPet('a')]);
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(petProvider).pets, isEmpty);
    },
  );

  test('logout clears notification contents and unread badge', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(authProvider);
    await until(() => !container.read(authProvider).isLoading);
    await container.read(notificationProvider.notifier).loadFirstPage();
    expect(container.read(notificationProvider).items.single.id, 'old');
    await container.read(authProvider.notifier).logout();
    expect(container.read(notificationProvider).items, isEmpty);
    expect(container.read(notificationProvider).unreadCount, 0);
    expect(await getAccessToken(), isNull);
  });

  test('old inbox response cannot populate a signed out session', () async {
    final pending = Completer<Object?>();
    final api = AuditApi(
      (r) => r.path == '/api/v1/notifications'
          ? pending.future
          : auditDefaultResponse(r),
    );
    useAuditApi(api);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(authProvider);
    await until(() => !container.read(authProvider).isLoading);
    final load = container.read(notificationProvider.notifier).loadFirstPage();
    await until(
      () => api.requests.any((r) => r.path == '/api/v1/notifications'),
    );
    await container.read(authProvider.notifier).logout();
    pending.complete(auditFeed(['old']));
    await load;
    expect(container.read(notificationProvider).items, isEmpty);
    expect(container.read(notificationProvider).unreadCount, 0);
  });

  test(
    'pet switch clears old records immediately and keeps them cleared on failure',
    () async {
      final pending = Completer<Object?>();
      final api = AuditApi(
        (r) => r.path == '/api/v1/pets/b/records'
            ? pending.future
            : auditDefaultResponse(r),
      );
      useAuditApi(api);
      final pet = PetNotifier.testWithServices(_loadedPets);
      addTearDown(pet.dispose);
      final switching = pet.setActivePet('b');
      final failure = expectLater(switching, throwsException);
      final during = pet.state.records.toList();
      await until(() => api.requests.any((r) => r.path.endsWith('/b/records')));
      pending.completeError(Exception('offline'));
      await failure;
      expect(during, isEmpty);
      expect(pet.state.activePetId, 'b');
      expect(pet.state.records, isEmpty);
    },
  );

  test(
    'older request for the same pet cannot overwrite a newer switch',
    () async {
      final pending = Completer<Object?>();
      var requests = 0;
      useAuditApi(
        AuditApi((r) {
          if (r.path == '/api/v1/pets/a/records') {
            requests++;
            return requests == 1 ? pending.future : [auditRecord('new', 'a')];
          }
          return auditDefaultResponse(r);
        }),
      );
      final pet = PetNotifier.testWithServices(_loadedPets);
      addTearDown(pet.dispose);
      final first = pet.setActivePet('a');
      await until(() => requests == 1);
      await pet.setActivePet('b');
      await pet.setActivePet('a');
      pending.complete([auditRecord('old', 'a')]);
      await first;
      expect(pet.state.records.single.id, 'new');
    },
  );

  test('concurrent loadMore appends each notification only once', () async {
    final pending = Completer<Object?>();
    useAuditApi(
      AuditApi(
        (r) => r.queryParameters['cursor'] == null
            ? auditFeed(['1'], cursor: 'next')
            : pending.future,
      ),
    );
    final notifier = NotificationNotifier(NotificationService());
    addTearDown(notifier.dispose);
    await notifier.loadFirstPage();
    final first = notifier.loadMore();
    final second = notifier.loadMore();
    pending.complete(auditFeed(['1', '2']));
    await Future.wait([first, second]);
    expect(notifier.state.items.map((n) => n.id), ['1', '2']);
  });

  test('refresh invalidates an older in-flight page append', () async {
    final pending = Completer<Object?>();
    useAuditApi(
      AuditApi(
        (r) => r.queryParameters['cursor'] == null
            ? auditFeed(['1'], cursor: 'next')
            : pending.future,
      ),
    );
    final notifier = NotificationNotifier(NotificationService());
    addTearDown(notifier.dispose);
    await notifier.loadFirstPage();
    final page = notifier.loadMore();
    await notifier.loadFirstPage();
    pending.complete(auditFeed(['stale']));
    await page;
    expect(notifier.state.items.map((n) => n.id), ['1']);
  });

  test(
    'late login token response after logout cannot restore credentials',
    () async {
      final pending = Completer<Object?>();
      final api = AuditApi(
        (r) => r.path == '/api/v1/auth/login'
            ? pending.future
            : auditDefaultResponse(r),
      );
      useAuditApi(api);
      final auth = AuthNotifier.test(
        const AuthState(isLoading: false, isAuthenticated: false),
      );
      addTearDown(auth.dispose);
      final login = auth.login(email: 'a@example.test', password: 'password');
      await until(
        () => api.requests.any((r) => r.path.endsWith('/auth/login')),
      );
      await auth.logout();
      pending.complete({
        'accessToken': 'late-access',
        'refreshToken': 'late-refresh',
      });
      await login;
      expect(auth.state.isAuthenticated, isFalse);
      expect(await getAccessToken(), isNull);
      expect(await getRefreshToken(), isNull);
    },
  );

  test(
    'old read-all success cannot mark the next account notifications read',
    () async {
      final pending = Completer<Object?>();
      var accountB = false;
      final api = AuditApi((r) {
        if (r.path.endsWith('/read-all')) return pending.future;
        if (r.path.endsWith('/auth/login')) {
          accountB = true;
          return {'accessToken': 'b-access', 'refreshToken': 'b-refresh'};
        }
        if (r.path == '/api/v1/users/me' && accountB) {
          return {'id': 'user-b', 'nickname': 'B', 'email': 'b@example.test'};
        }
        if (r.path == '/api/v1/notifications') {
          return auditFeed([accountB ? 'b' : 'a']);
        }
        return auditDefaultResponse(r);
      });
      useAuditApi(api);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider);
      await until(() => !container.read(authProvider).isLoading);
      final notifications = container.read(notificationProvider.notifier);
      await notifications.loadFirstPage();
      final mark = notifications.markAllRead();
      await until(() => api.requests.any((r) => r.path.endsWith('/read-all')));
      await container
          .read(authProvider.notifier)
          .login(email: 'b@example.test', password: 'password');
      expect(container.read(notificationProvider).items, isEmpty);
      await notifications.loadFirstPage();
      pending.complete(null);
      await mark;
      expect(container.read(authProvider).profile!.id, 'user-b');
      expect(notifications.state.items.single.id, 'b');
      expect(notifications.state.items.single.isRead, isFalse);
      expect(notifications.state.unreadCount, 1);
    },
  );

  test(
    'successful pet deletion is not reported failed when the next pet load fails',
    () async {
      useAuditApi(
        AuditApi((r) {
          if (r.path == '/api/v1/pets/b/records') throw Exception('offline');
          return auditDefaultResponse(r);
        }),
      );
      final pet = PetNotifier.testWithServices(_loadedPets);
      addTearDown(pet.dispose);
      await pet.deletePet('a');
      expect(pet.state.pets.map((p) => p.id), ['b']);
      expect(pet.state.records, isEmpty);
      expect(pet.state.dataErrorText, isNotNull);
    },
  );

  test(
    'late record creation after a pet switch cannot populate another pet',
    () async {
      final pending = Completer<Object?>();
      final api = AuditApi(
        (r) => r.method == 'POST' && r.path.endsWith('/records')
            ? pending.future
            : auditDefaultResponse(r),
      );
      useAuditApi(api);
      final pet = PetNotifier.testWithServices(_loadedPets);
      addTearDown(pet.dispose);
      final create = pet.addRecord({
        'typeId': 'weight',
        'date': '2026-09-08',
        'detail': {'weight': 4},
      });
      await until(() => api.requests.any((r) => r.method == 'POST'));
      await pet.setActivePet('b');
      pending.complete(auditRecord('created', 'a'));
      await create;
      expect(pet.state.activePetId, 'b');
      expect(pet.state.records, isEmpty);
    },
  );

  test(
    'late pet deletion after logout cannot alter the next authenticated session',
    () async {
      final pending = Completer<Object?>();
      final api = AuditApi(
        (r) => r.method == 'DELETE' ? pending.future : auditDefaultResponse(r),
      );
      useAuditApi(api);
      final pet = PetNotifier.testWithServices(_loadedPets);
      addTearDown(pet.dispose);
      final deletion = pet.deletePet('a');
      await until(() => api.requests.any((r) => r.method == 'DELETE'));
      await pet.clearForSignedOutUser();
      await pet.loadForAuthenticatedUser();
      pending.complete(null);
      await deletion;
      expect(pet.state.pets.map((p) => p.id), ['a', 'b']);
    },
  );

  test('old mark-read failure is discarded after account switch', () async {
    final pending = Completer<Object?>();
    final api = AuditApi(
      (r) => r.method == 'PATCH' ? pending.future : auditFeed(['1']),
    );
    useAuditApi(api);
    final notifier = NotificationNotifier(NotificationService());
    addTearDown(notifier.dispose);
    await notifier.loadFirstPage();
    final mark = notifier.markRead('1');
    final result = expectLater(mark, completes);
    await until(() => api.requests.any((r) => r.method == 'PATCH'));
    notifier.resetSession(authenticated: true);
    await notifier.loadFirstPage();
    pending.completeError(Exception('old session expired'));
    await result;
    expect(notifier.state.items.single.isRead, isFalse);
    expect(notifier.state.unreadCount, 1);
  });

  final routineJson = {
    'id': 'r',
    'petId': 'a',
    'label': 'Current routine',
    'typeId': 'walk',
    'repeatType': 'daily',
    'times': ['09:00'],
    'days': [],
    'startDate': '2026-09-01',
  };
  final scheduleJson = {
    'id': 's',
    'petId': 'a',
    'title': 'Current schedule',
    'categoryId': 'hospital',
    'startDate': '2026-09-08',
    'endDate': '2026-09-08',
    'allDay': true,
    'createdAt': '2026-09-01',
  };
  final schedule = CareSchedule.fromJson(scheduleJson);
  final operations = <String, Future<void> Function(PetNotifier)>{
    'pet creation': (p) => p.addPet(auditPet('late')),
    'pet update': (p) => p.updatePet('a', {'name': 'Late pet'}),
    'record update': (p) => p.updateRecord('old', {
      'detail': {'weight': 99},
    }),
    'record delete': (p) => p.deleteRecord('old'),
    'routine creation': (p) => p.addRoutine({...routineJson, 'id': 'late'}),
    'routine update': (p) => p.updateRoutine('r', {'label': 'Late routine'}),
    'routine delete': (p) => p.deleteRoutine('r'),
    'schedule creation': (p) async {
      await p.addCareSchedule(schedule);
    },
    'schedule update': (p) async {
      await p.updateCareSchedule(schedule);
    },
    'schedule delete': (p) => p.deleteCareSchedule('s'),
    'routine completion': (p) => p.toggleRoutineCompletion('r', '2026-09-08'),
  };
  for (final operation in operations.entries) {
    test(
      'late ${operation.key} response cannot alter the next session',
      () async {
        final pending = Completer<Object?>();
        final api = AuditApi((r) {
          if (r.method != 'GET') return pending.future;
          if (r.path.endsWith('/records')) return [auditRecord('old', 'a')];
          if (r.path.endsWith('/routines')) return [routineJson];
          if (r.path.endsWith('/care-schedules')) return [scheduleJson];
          return auditDefaultResponse(r);
        });
        useAuditApi(api);
        final pet = PetNotifier.testWithServices(
          _loadedPets.copyWith(
            routines: [Routine.fromJson(routineJson)],
            schedules: [schedule],
          ),
          scheduleService: CareScheduleService(),
        );
        addTearDown(pet.dispose);
        final mutation = operation.value(pet);
        await until(() => api.requests.any((r) => r.method != 'GET'));
        await pet.clearForSignedOutUser();
        await pet.loadForAuthenticatedUser();
        final response = switch (operation.key) {
          'pet creation' => auditPet('late'),
          'pet update' => {...auditPet('a'), 'name': 'Late pet'},
          'record update' => {
            ...auditRecord('old', 'a'),
            'detail': {'weight': 99},
          },
          'routine creation' => {...routineJson, 'id': 'late'},
          'routine update' => {...routineJson, 'label': 'Late routine'},
          'schedule creation' => {...scheduleJson, 'id': 'late'},
          'schedule update' => {...scheduleJson, 'title': 'Late schedule'},
          'routine completion' => {
            'id': 'c',
            'routineId': 'r',
            'petId': 'a',
            'scheduledDate': '2026-09-08',
            'status': 'COMPLETED',
          },
          _ => null,
        };
        pending.complete(response);
        await mutation;
        expect(pet.state.pets.map((p) => p.name), ['Pet a', 'Pet b']);
        expect(pet.state.records.map((r) => r.detail['weight']), [4]);
        expect(pet.state.routines.map((r) => r.label), ['Current routine']);
        expect(pet.state.schedules.map((s) => s.title), ['Current schedule']);
        expect(pet.state.routineCompletions, isEmpty);
      },
    );
  }
}

final _loadedPets = PetState(
  isLoading: false,
  hasOnboarded: true,
  pets: [Pet.fromJson(auditPet('a')), Pet.fromJson(auditPet('b'))],
  activePetId: 'a',
  records: [ActivityRecord.fromJson(auditRecord('old', 'a'))],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);
