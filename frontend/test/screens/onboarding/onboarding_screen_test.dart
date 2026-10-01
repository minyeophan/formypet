import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/onboarding/onboarding_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:frontend/widgets/pet_form_fields.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('registration offers adoption and optional edit information', (
    tester,
  ) async {
    await _pump(tester, PetEntryMode.firstPet);
    expect(find.byType(PetDateField), findsNWidgets(2));
    final extra = find.text('추가 정보 (선택)');
    await tester.ensureVisible(extra);
    await tester.tap(extra);
    await tester.pumpAndSettle();
    expect(find.text('성격'), findsOneWidget);
    expect(find.text('주치의·병원'), findsOneWidget);
  });

  testWidgets('first pet onboarding has shared title without back', (
    tester,
  ) async {
    await _pump(tester, PetEntryMode.firstPet);

    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.text('반려동물 등록'), findsOneWidget);
    expect(find.byType(AppBackButton), findsNothing);
    expect(find.text('색상'), findsNothing);
    expect(find.text('소동물'), findsOneWidget);
    expect(find.text('이색(기타)'), findsOneWidget);
    expect(find.text('품종/하위종'), findsOneWidget);
    expect(find.byType(PetTextField), findsOneWidget);
    expect(find.byType(PetDateField), findsNWidgets(2));
    expect(find.byType(PetPickerField), findsOneWidget);
    expect(find.byType(PetChoiceButton), findsWidgets);
  });

  testWidgets('onboarding requires name but allows unknown birthDate', (
    tester,
  ) async {
    final notifier = _AddPetNotifier(_state());
    await _pumpWithNotifier(tester, PetEntryMode.firstPet, notifier);

    final submitButton = find.widgetWithText(ElevatedButton, '등록');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('반려동물 이름을 입력해 주세요.'), findsOneWidget);
    expect(notifier.createdBody, isNull);

    final nameField = find.byType(TextField).first;
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, '몽이');
    final unknownButton = find.widgetWithText(TextButton, '생년월일을 몰라요');
    await tester.ensureVisible(unknownButton);
    await tester.tap(unknownButton);
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(notifier.createdBody?['name'], '몽이');
    expect(notifier.createdBody?['species'], 'dog');
    expect(notifier.createdBody, isNot(contains('birthDate')));
    expect(notifier.createdBody, isNot(contains('accentColor')));
    expect(notifier.createdBody, isNot(contains('bgLight')));
  });

  testWidgets('additional pet onboarding back dismisses and falls back to my', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/pets/new',
      routes: [
        GoRoute(
          path: '/my',
          builder: (context, state) => const Scaffold(body: Text('my-root')),
        ),
        GoRoute(
          path: '/pets/new',
          builder: (context, state) =>
              const OnboardingScreen(mode: PetEntryMode.additionalPet),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petProvider.overrideWith((ref) => PetNotifier.test(_state())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBackButton), findsOneWidget);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('my-root'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, PetEntryMode mode) async {
  await _pumpWithNotifier(tester, mode, PetNotifier.test(_state()));
}

Future<void> _pumpWithNotifier(
  WidgetTester tester,
  PetEntryMode mode,
  PetNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(home: OnboardingScreen(mode: mode)),
    ),
  );
  await tester.pumpAndSettle();
}

PetState _state() => const PetState(
  isLoading: false,
  hasOnboarded: true,
  pets: [
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
  records: [],
  routines: [],
  todayRoutineItems: [],
  routineCompletions: {},
  quickTypeIds: [],
);

class _AddPetNotifier extends PetNotifier {
  _AddPetNotifier(super.initialState) : super.test();

  Map<String, dynamic>? createdBody;

  @override
  Future<void> addPet(
    Map<String, dynamic> body, {
    PetPhotoUpload? photo,
  }) async {
    createdBody = body;
  }
}
