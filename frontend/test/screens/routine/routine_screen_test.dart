import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/routine/routine_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('routine screen uses shared header and monthly calendar only', (
    tester,
  ) async {
    await _pumpRoutineScreen(tester, _petState());

    expect(find.text('케어 캘린더'), findsOneWidget);
    expect(find.text('반복 루틴과 중요한 일정을 함께 확인해요'), findsOneWidget);
    expect(find.byKey(const Key('routine-month-calendar')), findsOneWidget);
    expect(find.text('월간'), findsNothing);
    expect(find.text('주간'), findsNothing);
    expect(find.byKey(const Key('routine-add-button')), findsOneWidget);
    expect(find.byKey(const Key('schedule-add-button')), findsOneWidget);
  });

  testWidgets('selected date list uses label instead of note', (tester) async {
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

    expect(find.text('심장약'), findsOneWidget);
    expect(find.text('식후 복용'), findsOneWidget);
    expect(find.byKey(const Key('routine-complete-r1')), findsOneWidget);
    expect(find.text('예방접종 예약'), findsNothing);
  });

  testWidgets(
    'schedule list always shows sample badges and hides add buttons',
    (tester) async {
      await _pumpRoutineScreen(tester, _petState());

      await tester.tap(find.text('일정 목록'));
      await tester.pumpAndSettle();

      expect(find.text('예방접종 예약'), findsOneWidget);
      expect(find.text('미용 예약'), findsOneWidget);
      expect(find.text('샘플'), findsNWidgets(2));
      expect(find.byKey(const Key('routine-add-button')), findsNothing);
      expect(find.byKey(const Key('schedule-add-button')), findsNothing);
    },
  );
}

Future<void> _pumpRoutineScreen(WidgetTester tester, PetState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => PetNotifier.test(state))],
      child: const MaterialApp(home: RoutineScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

PetState _petState({List<Routine> routines = const []}) => PetState(
  isLoading: false,
  hasOnboarded: true,
  pets: [_pet('1')],
  activePetId: '1',
  records: const [],
  routines: routines,
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
