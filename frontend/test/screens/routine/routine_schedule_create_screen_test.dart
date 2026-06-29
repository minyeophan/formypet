import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/care_schedule.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/routine/routine_schedule_create_screen.dart';
import 'package:frontend/services/care_schedule_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('schedule form excludes photo and companion inputs', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('카테고리'), findsOneWidget);
    expect(find.text('일정 제목'), findsOneWidget);
    expect(find.text('일시'), findsOneWidget);
    expect(find.text('장소'), findsOneWidget);
    expect(find.text('지도에서 찾기'), findsOneWidget);
    expect(find.text('메모'), findsOneWidget);
    expect(find.text('알림 시점'), findsOneWidget);
    expect(find.text('동반자'), findsNothing);
    expect(find.text('사진'), findsNothing);
  });

  testWidgets('header has no save button and bottom save starts disabled', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byType(TextButton), findsNothing);
    ElevatedButton saveButton() =>
        tester.widget(find.byKey(const Key('schedule-save-button')));
    expect(saveButton().onPressed, isNull);
  });

  testWidgets('schedule save persists without preparing toast then returns', (
    tester,
  ) async {
    final notifier = _petNotifier();
    await _pumpScreen(tester, notifier: notifier);
    ElevatedButton saveButton() =>
        tester.widget(find.byKey(const Key('schedule-save-button')));

    expect(saveButton().onPressed, isNull);
    await tester.tap(find.byKey(const Key('schedule-category-grooming')));
    await tester.enterText(
      find.byKey(const Key('schedule-title-field')),
      '목욕 예약',
    );
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);

    await tester.ensureVisible(find.byKey(const Key('schedule-save-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('준비중'), findsNothing);
    expect(notifier.state.schedules, hasLength(1));
    expect(notifier.state.schedules.single.title, '목욕 예약');
    expect(notifier.state.schedules.single.categoryId, 'grooming');
    expect(notifier.state.schedules.single.startTime, '00:00');
    expect(find.textContaining('routine target date='), findsOneWidget);
  });

  testWidgets('all day hides time controls and map search shows toast', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byKey(const Key('schedule-start-time-button')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('schedule-all-day-switch')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-all-day-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-start-time-button')), findsNothing);

    await tester.ensureVisible(find.text('지도에서 찾기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지도에서 찾기'));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);
  });

  testWidgets('reminder picker only applies completed selection', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('하루 전'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('schedule-reminder-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-reminder-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-reminder-wheel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('record-picker-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('하루 전'), findsOneWidget);
  });

  testWidgets('edit mode pre-fills saved schedule values', (tester) async {
    await _pumpScreen(
      tester,
      editingSchedule: _schedule(
        categoryId: 'unknown-category',
        reminder: '알 수 없는 알림',
      ),
    );

    expect(find.text('일정 수정'), findsOneWidget);
    expect(find.text('기타'), findsOneWidget);
    expect(find.text('2시간 전'), findsNothing);
    expect(find.text('하루 전'), findsOneWidget);
    expect(find.text('2026.06.17'), findsOneWidget);
    expect(find.text('2026.06.18'), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
    expect(find.widgetWithText(TextField, '목욕 예약'), findsOneWidget);
    expect(find.widgetWithText(TextField, '동네 미용실'), findsOneWidget);
    expect(find.widgetWithText(TextField, '빗 챙기기'), findsOneWidget);
    expect(find.byKey(const Key('schedule-save-button')), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    expect(find.byKey(const Key('schedule-delete-button')), findsOneWidget);
    expect(find.text('일정 삭제'), findsOneWidget);
  });

  testWidgets('edit save replaces same schedule and opens detail route', (
    tester,
  ) async {
    final notifier = _petNotifier(schedules: [_schedule()]);
    await _pumpScreen(tester, notifier: notifier, editingSchedule: _schedule());

    await tester.enterText(
      find.byKey(const Key('schedule-title-field')),
      '수정한 목욕 예약',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('schedule-save-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-save-button')));
    await tester.pumpAndSettle();

    expect(notifier.state.schedules, hasLength(1));
    expect(notifier.state.schedules.single.id, 's1');
    expect(notifier.state.schedules.single.title, '수정한 목욕 예약');
    expect(find.text('schedule detail id=s1'), findsOneWidget);
  });

  testWidgets('edit save clears optional fields and all day times', (
    tester,
  ) async {
    final notifier = _petNotifier(schedules: [_schedule()]);
    await _pumpScreen(tester, notifier: notifier, editingSchedule: _schedule());

    await tester.ensureVisible(find.widgetWithText(TextField, '동네 미용실'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '동네 미용실'), '');
    await tester.enterText(find.widgetWithText(TextField, '빗 챙기기'), '');
    await tester.ensureVisible(
      find.byKey(const Key('schedule-all-day-switch')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-all-day-switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('schedule-save-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-save-button')));
    await tester.pumpAndSettle();

    final schedule = notifier.state.schedules.single;
    expect(schedule.place, isNull);
    expect(schedule.memo, isNull);
    expect(schedule.allDay, isTrue);
    expect(schedule.startTime, isNull);
    expect(schedule.endTime, isNull);
  });

  testWidgets(
    'edit delete confirmation removes schedule and opens routine date',
    (tester) async {
      final notifier = _petNotifier(schedules: [_schedule()]);
      await _pumpScreen(
        tester,
        notifier: notifier,
        editingSchedule: _schedule(),
      );

      await tester.ensureVisible(
        find.byKey(const Key('schedule-delete-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-delete-button')));
      await tester.pumpAndSettle();

      expect(find.text('일정을 삭제할까요?'), findsOneWidget);
      expect(find.text('삭제한 일정은 다시 되돌릴 수 없어요.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('schedule-delete-confirm-button')));
      await tester.pumpAndSettle();

      expect(notifier.state.schedules, isEmpty);
      expect(find.text('routine target date=2026-06-17'), findsOneWidget);
    },
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  PetNotifier? notifier,
  CareSchedule? editingSchedule,
}) async {
  final petNotifier = notifier ?? _petNotifier();
  final router = GoRouter(
    initialLocation: editingSchedule == null
        ? '/routine/schedule/new'
        : '/routine/schedule/${editingSchedule.id}/edit',
    routes: [
      GoRoute(
        path: '/routine/schedule/new',
        builder: (_, _) => const RoutineScheduleCreateScreen(),
      ),
      GoRoute(
        path: '/routine/schedule/:scheduleId/edit',
        builder: (_, _) =>
            RoutineScheduleCreateScreen(editingSchedule: editingSchedule),
      ),
      GoRoute(
        path: '/routine/schedule/:scheduleId',
        builder: (_, state) => Scaffold(
          body: Text(
            'schedule detail id=${state.pathParameters['scheduleId']}',
          ),
        ),
      ),
      GoRoute(
        path: '/routine',
        builder: (_, state) => Scaffold(
          body: Text(
            'routine target date=${state.uri.queryParameters['date']}',
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => petNotifier)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

PetNotifier _petNotifier({List<CareSchedule> schedules = const []}) =>
    PetNotifier.testWithServices(
      PetState(
        isLoading: false,
        hasOnboarded: true,
        pets: [_pet('1')],
        activePetId: '1',
        records: const [],
        routines: const [],
        schedules: schedules,
        todayRoutineItems: const [],
        routineCompletions: const {},
        quickTypeIds: const ['meal', 'water'],
      ),
      scheduleService: _FakeCareScheduleService(),
    );

Pet _pet(String id) => Pet(
  id: id,
  name: 'Pet $id',
  species: 'dog',
  birthDate: '2022-03-15',
  accentColor: '#F4A460',
  bgLight: '#FFF8F0',
);

CareSchedule _schedule({
  String categoryId = 'grooming',
  String reminder = '2시간 전',
}) => CareSchedule(
  id: 's1',
  petId: '1',
  categoryId: categoryId,
  title: '목욕 예약',
  startDate: '2026-06-17',
  startTime: '10:30',
  endDate: '2026-06-18',
  endTime: '11:00',
  allDay: false,
  place: '동네 미용실',
  memo: '빗 챙기기',
  reminder: reminder,
  createdAt: '2026-06-01T00:00:00.000',
);

class _FakeCareScheduleService extends CareScheduleService {
  @override
  Future<CareSchedule> createSchedule(
    String petId,
    CareSchedule schedule,
  ) async => CareSchedule(
    id: 'server-${schedule.id}',
    petId: schedule.petId,
    categoryId: schedule.categoryId,
    title: schedule.title,
    startDate: schedule.startDate,
    startTime: schedule.startTime,
    endDate: schedule.endDate,
    endTime: schedule.endTime,
    allDay: schedule.allDay,
    place: schedule.place,
    memo: schedule.memo,
    reminder: schedule.reminder,
    createdAt: '2026-06-01T00:00:00.000',
  );

  @override
  Future<CareSchedule> updateSchedule(
    String petId,
    String scheduleId,
    CareSchedule schedule,
  ) async => schedule;

  @override
  Future<void> deleteSchedule(String petId, String scheduleId) async {}
}
