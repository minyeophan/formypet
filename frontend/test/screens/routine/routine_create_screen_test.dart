import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/routine/routine_create_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('routine type cards use real saved type labels', (tester) async {
    await _pumpScreen(tester, _FakePetNotifier(_petState()));

    expect(find.text('투약'), findsOneWidget);
    expect(find.text('급식'), findsOneWidget);
    expect(find.text('병원'), findsOneWidget);
    expect(find.text('검진'), findsNothing);
    expect(find.text('놀이'), findsNothing);
    expect(find.text('커스텀'), findsNothing);
  });

  testWidgets('weekly save defaults today weekday and omits empty note', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState());
    await _pumpScreen(tester, notifier);
    await tester.tap(find.byKey(const Key('routine-type-medicine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('매주'));
    await tester.pumpAndSettle();

    final todayDay = DateTime.now().weekday % 7;
    final todayChip = tester.widget<ChoiceChip>(
      find.byKey(Key('routine-day-$todayDay')),
    );
    expect(todayChip.selected, isTrue);

    await tester.ensureVisible(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(notifier.addedRoutineBody, isNotNull);
    expect(notifier.addedRoutineBody!['label'], '투약');
    expect(notifier.addedRoutineBody!['typeId'], 'medicine');
    expect(notifier.addedRoutineBody!['repeatType'], 'weekly');
    expect(notifier.addedRoutineBody!['days'], [todayDay]);
    expect(notifier.addedRoutineBody!['times'], ['08:00']);
    expect(notifier.addedRoutineBody!['notificationEnabled'], isTrue);
    expect(notifier.addedRoutineBody!.containsKey('note'), isFalse);
  });

  testWidgets('routine time field opens shared time picker', (tester) async {
    await _pumpScreen(tester, _FakePetNotifier(_petState()));
    await tester.tap(find.byKey(const Key('routine-type-meal')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('routine-time-field')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-time-hour-wheel')), findsOneWidget);
  });

  testWidgets('routine save failure keeps screen and shows error', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState(), failAdd: true);
    await _pumpScreen(tester, notifier);
    await tester.tap(find.byKey(const Key('routine-type-medicine')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('저장에 실패했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byType(RoutineCreateScreen), findsOneWidget);
  });
}

Future<void> _pumpScreen(WidgetTester tester, _FakePetNotifier notifier) async {
  final router = GoRouter(
    initialLocation: '/routine/new',
    routes: [
      GoRoute(
        path: '/routine/new',
        builder: (_, _) => const RoutineCreateScreen(),
      ),
      GoRoute(
        path: '/routine',
        builder: (_, _) => const Scaffold(body: Text('routine target')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => notifier)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

PetState _petState() => PetState(
  isLoading: false,
  hasOnboarded: true,
  pets: const [
    Pet(
      id: '1',
      name: 'Pet 1',
      species: 'dog',
      birthDate: '2022-03-15',
      accentColor: '#F4A460',
      bgLight: '#FFF8F0',
    ),
  ],
  activePetId: '1',
  records: const [],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

class _FakePetNotifier extends PetNotifier {
  _FakePetNotifier(super.initialState, {this.failAdd = false}) : super.test();

  final bool failAdd;
  Map<String, dynamic>? addedRoutineBody;

  @override
  Future<void> addRoutine(Map<String, dynamic> body) async {
    if (failAdd) throw Exception('failed');
    addedRoutineBody = body;
  }
}
