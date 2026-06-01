import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/routine/routine_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('routine screen shows calendar shell and empty state', (
    tester,
  ) async {
    await _pumpRoutineScreen(tester, petState: _petState());

    expect(find.text('케어 캘린더'), findsOneWidget);
    expect(find.text('캘린더'), findsOneWidget);
    expect(find.text('일정 목록'), findsOneWidget);
    expect(find.text('루틴 추가'), findsOneWidget);
    expect(find.text('일정 추가'), findsOneWidget);
    expect(find.text('아직 등록된 케어가 없어요'), findsOneWidget);
  });

  testWidgets(
    'routine screen shows selected date routines and toggles status',
    (tester) async {
      final notifier = _FakePetNotifier(
        _petState(
          routines: const [
            Routine(
              id: 'r1',
              petId: '1',
              typeId: 'medicine',
              repeatType: 'daily',
              times: ['08:30'],
              days: [],
              note: '심장약',
              startDate: '2026-01-01',
            ),
          ],
        ),
      );
      await _pumpRoutineScreen(tester, notifier: notifier);

      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('심장약'), findsOneWidget);
      expect(find.text('매일'), findsOneWidget);
      expect(find.byKey(const Key('routine-complete-r1')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('routine-complete-r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('routine-complete-r1')));
      await tester.pump();

      expect(notifier.toggledRoutineId, 'r1');
      expect(notifier.toggledDate, isNotNull);
    },
  );

  testWidgets('monthly and weekly calendar modes can be switched', (
    tester,
  ) async {
    await _pumpRoutineScreen(tester, petState: _petState());

    expect(find.byKey(const Key('routine-month-calendar')), findsOneWidget);

    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('routine-week-calendar')), findsOneWidget);
  });

  testWidgets('schedule list tab shows sample schedules after care exists', (
    tester,
  ) async {
    await _pumpRoutineScreen(
      tester,
      petState: _petState(
        routines: const [
          Routine(
            id: 'r1',
            petId: '1',
            typeId: 'meal',
            repeatType: 'daily',
            times: ['09:00'],
            days: [],
            startDate: '2026-01-01',
          ),
        ],
      ),
    );

    await tester.tap(find.text('일정 목록'));
    await tester.pumpAndSettle();

    expect(find.text('예방접종 예약'), findsOneWidget);
    expect(find.text('미용 예약'), findsOneWidget);
  });

  testWidgets('/routine/new shows type cards and saves addRoutine payload', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState());
    await _pumpAppRouter(
      tester,
      initialLocation: '/routine/new',
      notifier: notifier,
    );

    expect(find.text('투약'), findsOneWidget);
    expect(find.text('급식'), findsOneWidget);
    expect(find.text('건강체크'), findsOneWidget);
    expect(find.text('특별케어'), findsOneWidget);
    expect(find.text('커스텀'), findsOneWidget);

    await tester.tap(find.text('투약'));
    await tester.pumpAndSettle();

    expect(find.text('루틴 정보'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('routine-name-field')), '심장약');
    await tester.enterText(find.byKey(const Key('routine-note-field')), '식후');
    await tester.enterText(
      find.byKey(const Key('routine-time-field')),
      '08:40',
    );
    await tester.ensureVisible(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(notifier.addedRoutineBody, isNotNull);
    expect(notifier.addedRoutineBody!['typeId'], 'medicine');
    expect(notifier.addedRoutineBody!['repeatType'], 'daily');
    expect(notifier.addedRoutineBody!['times'], ['08:40']);
    expect(notifier.addedRoutineBody!['days'], <int>[]);
    expect(notifier.addedRoutineBody!['label'], '심장약');
    expect(notifier.addedRoutineBody!['note'], '식후');
    expect(find.text('케어 캘린더'), findsOneWidget);
  });

  testWidgets('/routine/schedule/new shows form sections and preparing toast', (
    tester,
  ) async {
    await _pumpAppRouter(tester, initialLocation: '/routine/schedule/new');

    expect(find.text('일정 추가'), findsOneWidget);
    expect(find.text('카테고리'), findsOneWidget);
    expect(find.text('제목'), findsOneWidget);
    expect(find.text('일시'), findsOneWidget);
    expect(find.text('장소'), findsOneWidget);
    expect(find.text('동반자'), findsOneWidget);
    expect(find.text('메모'), findsOneWidget);
    expect(find.text('알림 시점'), findsOneWidget);

    await tester.ensureVisible(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.text('준비중'), findsOneWidget);
  });
}

Future<void> _pumpRoutineScreen(
  WidgetTester tester, {
  PetState? petState,
  _FakePetNotifier? notifier,
}) async {
  final fakeNotifier = notifier ?? _FakePetNotifier(petState ?? _petState());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => fakeNotifier)],
      child: const MaterialApp(home: RoutineScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAppRouter(
  WidgetTester tester, {
  required String initialLocation,
  _FakePetNotifier? notifier,
}) async {
  final fakeNotifier = notifier ?? _FakePetNotifier(_petState());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.test(
            const AuthState(isLoading: false, isAuthenticated: true),
          ),
        ),
        petProvider.overrideWith((ref) => fakeNotifier),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final router = ref.watch(routerProvider);
          router.go(initialLocation);
          return MaterialApp.router(routerConfig: router);
        },
      ),
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

class _FakePetNotifier extends PetNotifier {
  _FakePetNotifier(super.initialState) : super.test();

  Map<String, dynamic>? addedRoutineBody;
  String? toggledRoutineId;
  String? toggledDate;

  @override
  Future<void> addRoutine(Map<String, dynamic> body) async {
    addedRoutineBody = body;
    state = state.copyWith(
      routines: [
        ...state.routines,
        Routine(
          id: 'created',
          petId: state.activePetId!,
          typeId: body['typeId'] as String,
          repeatType: body['repeatType'] as String,
          times: List<String>.from(body['times'] as List),
          days: List<int>.from(body['days'] as List),
          startDate: body['startDate'] as String,
          note: body['note'] as String?,
        ),
      ],
    );
  }

  @override
  Future<void> toggleRoutineCompletion(String routineId, String date) async {
    toggledRoutineId = routineId;
    toggledDate = date;
  }
}
