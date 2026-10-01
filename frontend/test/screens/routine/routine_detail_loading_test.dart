import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/care_schedule.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/routine/routine_detail_screen.dart';
import 'package:frontend/screens/routine/routine_schedule_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

const _schedule = CareSchedule(
  id: 's1',
  petId: 'p1',
  categoryId: 'grooming',
  title: 'Bath',
  startDate: '2026-09-21',
  endDate: '2026-09-21',
  allDay: true,
  reminder: '없음',
  createdAt: '2026-09-01',
);

PetState _state({
  bool loading = false,
  String? error,
  List<CareSchedule> schedules = const [],
  List<Routine> routines = const [],
  String petId = 'p1',
}) => PetState(
  isLoading: loading,
  dataErrorText: error,
  hasOnboarded: true,
  pets: const [],
  activePetId: petId,
  records: const [],
  routines: routines,
  schedules: schedules,
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

class _FakePets extends PetNotifier {
  _FakePets(super.initialState) : super.test();
  void emit(PetState next) => state = next;
  @override
  Future<void> retryDataLoad() async => emit(_state());
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final entry in <String, Widget>{
    'routine detail': const RoutineDetailScreen(routineId: 'r1'),
    'schedule detail': const RoutineScheduleDetailScreen(scheduleId: 's1'),
    'schedule edit': const RoutineScheduleEditScreen(scheduleId: 's1'),
  }.entries) {
    testWidgets(
      '${entry.key} waits for loading and retries errors before missing',
      (tester) async {
        final notifier = _FakePets(_state(loading: true));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [petProvider.overrideWith((ref) => notifier)],
            child: MaterialApp(home: entry.value),
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('찾을 수'), findsNothing);
        notifier.emit(_state(error: 'Failed to load'));
        await tester.pump();
        expect(find.text('Failed to load'), findsOneWidget);
        expect(find.textContaining('찾을 수'), findsNothing);
        await tester.tap(find.text('다시 시도'));
        await tester.pump();
        expect(find.textContaining('찾을 수'), findsOneWidget);
        expect(find.text('다시 시도'), findsNothing);
      },
    );
  }

  testWidgets('routine direct lookup renders data after initial loading', (
    tester,
  ) async {
    final notifier = _FakePets(_state(loading: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: RoutineDetailScreen(routineId: 'r1')),
      ),
    );
    notifier.emit(
      _state(
        routines: const [
          Routine(
            id: 'r1',
            petId: 'p1',
            label: 'Morning walk',
            typeId: 'walk',
            repeatType: 'daily',
            times: [],
            days: [],
            startDate: '2026-09-21',
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.textContaining('찾을 수'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  for (final screen in [
    const RoutineScheduleDetailScreen(scheduleId: 's1'),
    const RoutineScheduleEditScreen(scheduleId: 's1'),
  ]) {
    testWidgets(
      '${screen.runtimeType} renders after initial load and retains cached data on error',
      (tester) async {
        final notifier = _FakePets(_state(loading: true));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [petProvider.overrideWith((ref) => notifier)],
            child: MaterialApp(home: screen),
          ),
        );
        notifier.emit(_state(schedules: [_schedule]));
        await tester.pump();
        expect(find.text('Bath'), findsOneWidget);
        notifier.emit(_state(schedules: [_schedule], error: 'Refresh failed'));
        await tester.pump();
        expect(find.text('Bath'), findsOneWidget);
        expect(find.textContaining('찾을 수'), findsNothing);
      },
    );
  }

  testWidgets(
    'schedule edit preserves draft through refresh but not a pet switch',
    (tester) async {
      final notifier = _FakePets(_state(schedules: [_schedule]));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [petProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(
            home: RoutineScheduleEditScreen(scheduleId: 's1'),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('schedule-title-field')),
        'Unsaved title',
      );
      notifier.emit(_state(loading: true));
      await tester.pump();
      expect(find.text('Unsaved title'), findsOneWidget);
      notifier.emit(_state(error: 'Refresh failed'));
      await tester.pump();
      expect(find.text('Unsaved title'), findsOneWidget);
      notifier.emit(_state(schedules: [_schedule]));
      await tester.pump();
      expect(find.text('Unsaved title'), findsOneWidget);
      notifier.emit(_state(petId: 'p2'));
      await tester.pump();
      expect(find.text('Unsaved title'), findsNothing);
      expect(find.textContaining('찾을 수'), findsOneWidget);
    },
  );
}
