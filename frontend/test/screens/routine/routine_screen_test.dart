import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/care_schedule.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/routine/routine_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('routine screen shows schedule-only calendar actions', (
    tester,
  ) async {
    await _pumpRoutineScreen(tester, _petState());

    expect(find.text('케어 캘린더'), findsOneWidget);
    expect(find.text('중요한 케어 일정을 한눈에 확인해요'), findsOneWidget);
    expect(find.byKey(const Key('routine-month-calendar')), findsOneWidget);
    expect(find.text('월간'), findsNothing);
    expect(find.text('주간'), findsNothing);
    expect(find.byKey(const Key('routine-add-button')), findsNothing);
    expect(find.byKey(const Key('schedule-add-button')), findsOneWidget);
    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
  });

  testWidgets('routine fixtures are hidden from care calendar', (tester) async {
    await _pumpRoutineScreen(
      tester,
      _petState(
        routines: const [
          Routine(
            id: 'r1',
            petId: '1',
            label: '심장약',
            typeId: 'medicine',
            repeatType: 'daily',
            times: ['08:30'],
            days: [],
            note: '식후 복용',
            startDate: '2026-01-01',
          ),
        ],
      ),
    );

    expect(find.text('심장약'), findsNothing);
    expect(find.text('식후 복용'), findsNothing);
    expect(find.byKey(const Key('routine-complete-r1')), findsNothing);
    expect(find.text('예방접종 예약'), findsNothing);
  });

  testWidgets('saved schedules render on selected date and calendar dot', (
    tester,
  ) async {
    await _pumpRoutineScreen(
      tester,
      _petState(schedules: [_schedule('s1', '2026-06-17')]),
      initialDate: DateTime(2026, 6, 17),
    );

    expect(find.text('목욕 예약'), findsOneWidget);
    expect(find.text('6월 17일 10:30'), findsOneWidget);
    expect(
      find.byKey(const Key('routine-date-dot-2026-06-17')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('routine-date-dot-2026-06-18')), findsNothing);
  });

  testWidgets('schedule list shows saved schedules without sample badges', (
    tester,
  ) async {
    await _pumpRoutineScreen(
      tester,
      _petState(schedules: [_schedule('s1', '2026-06-17')]),
      initialDate: DateTime(2026, 6, 17),
    );

    await tester.tap(find.text('일정 목록'));
    await tester.pumpAndSettle();

    expect(find.text('목욕 예약'), findsOneWidget);
    expect(find.text('예방접종 예약'), findsNothing);
    expect(find.text('미용 예약'), findsNothing);
    expect(find.text('샘플'), findsNothing);
    expect(find.byKey(const Key('routine-add-button')), findsNothing);
    expect(find.byKey(const Key('schedule-add-button')), findsNothing);
  });
}

Future<void> _pumpRoutineScreen(
  WidgetTester tester,
  PetState state, {
  DateTime? initialDate,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => PetNotifier.test(state))],
      child: MaterialApp(home: RoutineScreen(initialDate: initialDate)),
    ),
  );
  await tester.pumpAndSettle();
}

PetState _petState({
  List<Routine> routines = const [],
  List<CareSchedule> schedules = const [],
}) => PetState(
  isLoading: false,
  hasOnboarded: true,
  pets: [_pet('1')],
  activePetId: '1',
  records: const [],
  routines: routines,
  schedules: schedules,
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const ['meal', 'water'],
);

Pet _pet(String id) => Pet(
  id: id,
  name: 'Pet $id',
  species: 'dog',
  birthDate: '2022-03-15',
  accentColor: '#F4A460',
  bgLight: '#FFF8F0',
);

CareSchedule _schedule(String id, String date) => CareSchedule(
  id: id,
  petId: '1',
  categoryId: 'grooming',
  title: '목욕 예약',
  startDate: date,
  startTime: '10:30',
  endDate: date,
  endTime: '11:00',
  allDay: false,
  place: '동네 미용실',
  memo: null,
  reminder: '하루 전',
  createdAt: '2026-06-01T00:00:00.000',
);
