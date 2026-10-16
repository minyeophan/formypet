// Isolated MuMu package and local JPA DB only. Always use --no-uninstall.
// VERIFY_EXISTING_ROUTINE=true reads fixtures from the previous process.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/routine_service.dart';
import 'package:frontend/services/care_schedule_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('JPA routine and care schedule CRUD and persistence', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    expect(
      (await getExternalStorageDirectory())!.path,
      contains('com.formypet.frontend.mediatest/'),
    );
    initApiClient('http://127.0.0.1:18083');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_ROUTINE');
    final routines = RoutineService();
    final schedules = CareScheduleService();
    if (!existing) {
      final random = Random.secure();
      await AuthService().register(
        email:
            'routine-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
        password: List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join(),
        nickname: 'JPA 루틴 검증',
      );
      final pet = await PetService().createPet({
        'name': '루틴 검증',
        'species': 'dog',
      });
      final now = DateTime.now();
      final date = now.toIso8601String().substring(0, 10);
      for (final repeat in ['daily', 'weekly', 'biweekly', 'monthly']) {
        await routines.createRoutine(pet.id, {
          'label': 'JPA $repeat',
          'typeId': 'water',
          'repeatType': repeat,
          'days': [now.weekday % 7],
          'monthlyInterval': 1,
          'startDate': date,
          'times': ['09:05', '23:10'],
          'note': '보존할 메모',
          'notificationEnabled': false,
        });
      }
      await dio.post(
        '/api/v1/pets/${pet.id}/care-schedules',
        data: {
          'categoryId': 'hospital',
          'title': 'JPA 종일',
          'startDate': date,
          'endDate': date,
          'startTime': '09:05',
          'endTime': '23:10',
          'allDay': true,
          'place': '검증 장소',
          'memo': '일정 메모',
          'reminder': 'none',
        },
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
    final pet = (await PetService().getPets()).single;
    final router = container.read(routerProvider);
    final daily = (await routines.getRoutines(
      pet.id,
    )).singleWhere((r) => r.repeatType == 'daily');
    final date = daily.startDate;

    if (!existing) {
      router.go('/routine/new');
      await _until(
        tester,
        () => find.byKey(const Key('routine-name-field')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('routine-name-field')),
        'JPA 삭제 루틴',
      );
      await _hideKeyboard(tester);
      await _tap(tester, find.byKey(const Key('routine-category-meal')));
      await _tap(tester, find.text('저장'));
      await _until(
        tester,
        () => container.read(petProvider).routines.length == 5,
      );
      final temporary = (await routines.getRoutines(
        pet.id,
      )).singleWhere((r) => r.label == 'JPA 삭제 루틴');
      router.go('/routine/${temporary.id}/edit');
      await _until(
        tester,
        () => find
            .byKey(const Key('routine-delete-button'))
            .evaluate()
            .isNotEmpty,
      );
      await _tap(tester, find.byKey(const Key('routine-delete-button')));
      await _tap(tester, find.text('취소'));
      expect((await routines.getRoutines(pet.id)).length, 5);
      await _tap(tester, find.byKey(const Key('routine-delete-button')));
      await _tap(
        tester,
        find.byKey(const Key('routine-delete-confirm-button')),
      );
      await _until(
        tester,
        () => container.read(petProvider).routines.length == 4,
      );

      router.go('/routine/${daily.id}/edit');
      await _until(
        tester,
        () => find.byKey(const Key('routine-name-field')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('routine-name-field')),
        'JPA daily 수정',
      );
      await _hideKeyboard(tester);
      await _tap(tester, find.text('저장'));
      await _until(
        tester,
        () => container
            .read(petProvider)
            .routines
            .any((r) => r.label == 'JPA daily 수정'),
      );

      // Completion controls are not exposed by the current screens. Exercise the
      // real app service/API from MuMu, including repeated today reads.
      for (final status in [
        CompletionStatus.completed,
        CompletionStatus.pending,
        CompletionStatus.skipped,
        CompletionStatus.completed,
      ]) {
        final completion = await routines.patchCompletion(
          petId: pet.id,
          routineId: daily.id,
          date: date,
          status: status,
        );
        expect(completion.status, status);
        final today =
            unwrap(
                  await dio.get(
                    '/api/v1/pets/${pet.id}/routines/today',
                    queryParameters: {'date': date},
                  ),
                )
                as Map<String, dynamic>;
        final rows = today['routines'] as List<dynamic>;
        expect(rows.length, 4);
        final row = rows.singleWhere(
          (r) => r['routine']['id'].toString() == daily.id,
        );
        expect(row['completion']['status'], status.name.toUpperCase());
      }

      final allDay = (await schedules.getSchedules(pet.id)).single;
      router.go('/routine/schedule/${allDay.id}/edit');
      await _until(
        tester,
        () =>
            find.byKey(const Key('schedule-title-field')).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('schedule-title-field')),
        'JPA 종일 수정',
      );
      await _hideKeyboard(tester);
      await _tap(tester, find.byKey(const Key('schedule-save-button')));
      await _until(
        tester,
        () => container
            .read(petProvider)
            .schedules
            .any((s) => s.title == 'JPA 종일 수정'),
      );
      router.go('/routine/schedule/new');
      await _until(
        tester,
        () =>
            find.byKey(const Key('schedule-title-field')).evaluate().isNotEmpty,
      );
      await _tap(tester, find.byKey(const Key('schedule-category-grooming')));
      await tester.enterText(
        find.byKey(const Key('schedule-title-field')),
        'JPA 삭제 일정',
      );
      await _hideKeyboard(tester);
      await _tap(tester, find.byKey(const Key('schedule-save-button')));
      await _until(
        tester,
        () => container.read(petProvider).schedules.length == 2,
      );
      final temporarySchedule = (await schedules.getSchedules(
        pet.id,
      )).singleWhere((s) => s.title == 'JPA 삭제 일정');
      router.go('/routine/schedule/${temporarySchedule.id}/edit');
      await _until(
        tester,
        () => find
            .byKey(const Key('schedule-delete-button'))
            .evaluate()
            .isNotEmpty,
      );
      await _tap(tester, find.byKey(const Key('schedule-delete-button')));
      await _tap(tester, find.text('취소'));
      expect((await schedules.getSchedules(pet.id)).length, 2);
      await _tap(tester, find.byKey(const Key('schedule-delete-button')));
      await _tap(
        tester,
        find.byKey(const Key('schedule-delete-confirm-button')),
      );
      await _until(
        tester,
        () => container.read(petProvider).schedules.length == 1,
      );
    }
    final saved = await routines.getRoutines(pet.id);
    expect(saved.length, 4);
    final savedDaily = saved.singleWhere((r) => r.id == daily.id);
    expect(savedDaily.label, 'JPA daily 수정');
    expect(savedDaily.times, ['09:05', '23:10']);
    expect(savedDaily.note, '보존할 메모');
    expect(savedDaily.notificationEnabled, isFalse);
    final today =
        unwrap(
              await dio.get(
                '/api/v1/pets/${pet.id}/routines/today',
                queryParameters: {'date': date},
              ),
            )
            as Map<String, dynamic>;
    expect(today['summary']['total'], 4);
    expect(today['summary']['done'], 1);
    final schedule = (await schedules.getSchedules(pet.id)).single;
    expect(schedule.title, 'JPA 종일 수정');
    expect(schedule.allDay, isTrue);
    expect(schedule.startTime, isNull);
    expect(schedule.endTime, isNull);
    expect(schedule.place, '검증 장소');
    expect(schedule.memo, '일정 메모');
    expect(schedule.reminder, 'none');

    router.go('/routine?tab=routines');
    await _until(
      tester,
      () => find.byKey(Key('routine-item-${daily.id}')).evaluate().isNotEmpty,
    );
    for (final routine in saved) {
      await Scrollable.ensureVisible(
        tester.element(find.byKey(Key('routine-item-${routine.id}'))),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      expect(find.text(routine.label), findsOneWidget);
    }
    router.go('/routine/${daily.id}');
    await _until(tester, () => find.text('JPA daily 수정').evaluate().isNotEmpty);
    await tester.scrollUntilVisible(
      find.text('09:05\n23:10'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('09:05\n23:10').hitTestable(), findsOneWidget);
    router.go('/routine/schedule/${schedule.id}');
    await _until(tester, () => find.text('JPA 종일 수정').evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'ROUTINE_RESTART_VERIFIED' : 'ROUTINE_UI_VERIFIED');
  });
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Routine UI did not become ready');
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}
