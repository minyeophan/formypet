import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/routine/routine_schedule_create_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
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
    await tester.tap(find.text('미용'));
    await tester.enterText(
      find.byKey(const Key('schedule-title-field')),
      '목욕 예약',
    );
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);

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
}

Future<void> _pumpScreen(WidgetTester tester, {PetNotifier? notifier}) async {
  final petNotifier = notifier ?? _petNotifier();
  final router = GoRouter(
    initialLocation: '/routine/schedule/new',
    routes: [
      GoRoute(
        path: '/routine/schedule/new',
        builder: (_, _) => const RoutineScheduleCreateScreen(),
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

PetNotifier _petNotifier() => PetNotifier.test(
  PetState(
    isLoading: false,
    hasOnboarded: true,
    pets: [_pet('1')],
    activePetId: '1',
    records: const [],
    routines: const [],
    todayRoutineItems: const [],
    routineCompletions: const {},
    quickTypeIds: const ['meal', 'water'],
  ),
);

Pet _pet(String id) => Pet(
  id: id,
  name: 'Pet $id',
  species: 'dog',
  birthDate: '2022-03-15',
  accentColor: '#F4A460',
  bgLight: '#FFF8F0',
);
