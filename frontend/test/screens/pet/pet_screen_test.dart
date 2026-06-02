import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/pet/pet_detail_screen.dart';
import 'package:frontend/screens/pet/pet_edit_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('pet detail distinguishes loading from missing id', (
    tester,
  ) async {
    final notifier = _MutablePetNotifier(_state(isLoading: true));
    await _pump(tester, PetDetailScreen(petId: 'missing'), notifier);

    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.text('반려동물 상세'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('반려동물을 찾을 수 없습니다'), findsNothing);

    notifier.replace(_state());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('반려동물을 찾을 수 없습니다'), findsOneWidget);
  });

  testWidgets('pet detail normal state uses shared header edit action', (
    tester,
  ) async {
    await _pump(
      tester,
      const PetDetailScreen(petId: '1'),
      _MutablePetNotifier(_state()),
    );

    expect(find.text('Pet 1'), findsWidgets);
    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.byType(AppHeaderIconButton), findsOneWidget);
  });

  testWidgets('pet edit hydrates after provider loading and preserves edits', (
    tester,
  ) async {
    final notifier = _MutablePetNotifier(_state(isLoading: true));
    await _pump(tester, const PetEditScreen(petId: '1'), notifier);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    notifier.replace(_state());
    await tester.pumpAndSettle();

    final field = find.byType(TextField).first;
    expect(tester.widget<TextField>(field).controller!.text, 'Pet 1');

    await tester.enterText(field, '사용자 수정');
    notifier.replace(_state(pets: [_pet('1'), _pet('2')]));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller!.text, '사용자 수정');
  });

  testWidgets('pet edit missing id shows error instead of throwing', (
    tester,
  ) async {
    await _pump(
      tester,
      const PetEditScreen(petId: 'missing'),
      _MutablePetNotifier(_state()),
    );

    expect(find.text('반려동물을 찾을 수 없습니다'), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.text('저장'), findsNothing);
  });

  testWidgets('pet direct URL back uses my fallback', (tester) async {
    final notifier = _MutablePetNotifier(_state());
    await _pumpRouter(tester, '/pet/1', notifier);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('my-root'), findsOneWidget);
  });

  testWidgets('pet edit direct URL back uses detail or my fallback', (
    tester,
  ) async {
    final notifier = _MutablePetNotifier(_state());
    await _pumpRouter(tester, '/pet/1/edit', notifier);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.byType(PetDetailScreen), findsOneWidget);

    await _pumpRouter(tester, '/pet/missing/edit', notifier);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('my-root'), findsOneWidget);
  });

  testWidgets('last pet deletion stays put for router redirect', (
    tester,
  ) async {
    final notifier = _DeletePetNotifier(_state());
    await _pumpRouter(tester, '/pet/1', notifier);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
    await tester.pumpAndSettle();

    expect(notifier.deletedIds, ['1']);
    expect(find.text('반려동물을 찾을 수 없습니다'), findsOneWidget);
    expect(find.text('my-root'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  PetNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump();
}

Future<void> _pumpRouter(
  WidgetTester tester,
  String initialLocation,
  PetNotifier notifier,
) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/my',
        builder: (context, state) => const Scaffold(body: Text('my-root')),
      ),
      GoRoute(
        path: '/pet/:id',
        builder: (context, state) =>
            PetDetailScreen(petId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pet/:id/edit',
        builder: (context, state) =>
            PetEditScreen(petId: state.pathParameters['id']!),
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

PetState _state({bool isLoading = false, List<Pet>? pets}) => PetState(
  isLoading: isLoading,
  hasOnboarded: true,
  pets: pets ?? [_pet('1')],
  activePetId: '1',
  records: const [],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

Pet _pet(String id) => Pet(
  id: id,
  name: 'Pet $id',
  species: 'dog',
  birthDate: '2022-03-15',
  accentColor: '#F4A460',
  bgLight: '#FFF8F0',
);

class _MutablePetNotifier extends PetNotifier {
  _MutablePetNotifier(super.initialState) : super.test();

  void replace(PetState next) {
    state = next;
  }
}

class _DeletePetNotifier extends _MutablePetNotifier {
  _DeletePetNotifier(super.initialState);

  final deletedIds = <String>[];

  @override
  Future<void> deletePet(String petId) async {
    deletedIds.add(petId);
    replace(
      const PetState(
        isLoading: false,
        hasOnboarded: false,
        pets: [],
        records: [],
        routines: [],
        todayRoutineItems: [],
        routineCompletions: {},
        quickTypeIds: [],
      ),
    );
  }
}
