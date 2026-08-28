import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/core/pet_taxonomy.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/pet/pet_confirm_dialog.dart';
import 'package:frontend/screens/pet/pet_detail_screen.dart';
import 'package:frontend/screens/pet/pet_edit_screen.dart';
import 'package:frontend/services/record_service.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:frontend/widgets/pet_form_fields.dart';
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

  testWidgets(
    'pet detail shows neutered under gender and hides registration number',
    (tester) async {
      final recordService = _FakeRecordService({
        '2': [
          _weightRecord('a', '2', '2024-01-01', '21:00', {'value': 4.1}),
          _weightRecord('b', '2', '2024-01-02', '08:00', {'weight': 5.2}),
          _weightRecord('c', '2', '2024-01-02', '18:30', {'value': 5.8}),
        ],
      });

      await _pump(
        tester,
        const PetDetailScreen(petId: '2'),
        _MutablePetNotifier(
          _state(
            activePetId: '1',
            pets: [
              _pet('1'),
              _pet(
                '2',
                gender: 'male',
                neutered: false,
                animalRegistrationNumber: '410000000000001',
              ),
            ],
          ),
        ),
        recordService: recordService,
      );
      await tester.pumpAndSettle();

      expect(recordService.requests.single.petId, '2');
      expect(recordService.requests.single.typeId, 'weight');
      expect(recordService.requests.single.limit, isNull);
      expect(find.text('나이'), findsOneWidget);
      expect(find.text('최근 체중'), findsOneWidget);
      expect(find.text('성별'), findsOneWidget);
      expect(find.text('중성화'), findsOneWidget);
      expect(find.text('미완료'), findsOneWidget);
      expect(find.text('동물등록번호'), findsNothing);
      expect(find.text('5.8kg'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('성별')).dy,
        lessThan(tester.getTopLeft(find.text('중성화')).dy),
      );
    },
  );

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

  testWidgets('pet edit groups fields into the planned sections', (
    tester,
  ) async {
    await _pump(
      tester,
      const PetEditScreen(petId: '1'),
      _MutablePetNotifier(_state()),
    );
    await tester.pumpAndSettle();

    final identity = find.byKey(const Key('pet-edit-identity-section'));
    final profile = find.byKey(const Key('pet-edit-profile-section'));
    final extra = find.byKey(const Key('pet-edit-extra-section'));

    expect(identity, findsOneWidget);
    expect(profile, findsOneWidget);
    expect(extra, findsOneWidget);
    expect(_inside(identity, '이름'), findsOneWidget);
    expect(_inside(identity, '종'), findsOneWidget);
    expect(_inside(identity, '품종/하위종'), findsOneWidget);
    expect(_inside(profile, '생년월일'), findsOneWidget);
    expect(_inside(profile, '함께한 날'), findsOneWidget);
    expect(_inside(profile, '성별'), findsOneWidget);
    expect(_inside(profile, '중성화 여부'), findsOneWidget);
    expect(_inside(extra, '특수상태'), findsOneWidget);
    expect(_inside(extra, '성격'), findsOneWidget);
    expect(_inside(extra, '보호자 호칭'), findsOneWidget);
    expect(_inside(extra, '알러지·특이사항'), findsOneWidget);
    expect(_inside(extra, '질병'), findsOneWidget);
    expect(_inside(extra, '주치의·병원'), findsOneWidget);
  });

  testWidgets('pet edit uses stable input structures', (tester) async {
    await _pump(
      tester,
      const PetEditScreen(petId: '1'),
      _MutablePetNotifier(_state()),
    );
    await tester.pumpAndSettle();

    final identity = find.byKey(const Key('pet-edit-identity-section'));
    final profile = find.byKey(const Key('pet-edit-profile-section'));
    final extra = find.byKey(const Key('pet-edit-extra-section'));

    final speciesGrid = tester.widget<GridView>(
      find.descendant(
        of: identity,
        matching: find.byKey(const Key('pet-edit-species-grid')),
      ),
    );
    final gridDelegate =
        speciesGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    final childrenDelegate =
        speciesGrid.childrenDelegate as SliverChildBuilderDelegate;
    expect(gridDelegate.crossAxisCount, 3);
    expect(childrenDelegate.childCount, kPetSpecies.length);
    expect(
      find.descendant(of: identity, matching: find.byType(PetChoiceButton)),
      findsNWidgets(kPetSpecies.length),
    );

    expect(
      find.descendant(of: profile, matching: find.byType(PetDateField)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: profile, matching: find.byType(TextField)),
      findsNothing,
    );

    final twoChoiceRows = tester
        .widgetList<Row>(
          find.descendant(of: profile, matching: find.byType(Row)),
        )
        .where((row) => _expandedChildCount(row) == 2)
        .toList();
    expect(twoChoiceRows, hasLength(2));

    final statusRows = tester
        .widgetList<Row>(find.descendant(of: extra, matching: find.byType(Row)))
        .where((row) => _expandedChildCount(row) == 4)
        .toList();
    expect(statusRows, hasLength(1));
    final statusButtons = tester.widgetList<PetChoiceButton>(
      find.descendant(of: extra, matching: find.byType(PetChoiceButton)),
    );
    expect(statusButtons, hasLength(4));
    expect(statusButtons.every((button) => button.dense), isTrue);
  });

  testWidgets('pet edit date field opens the date picker sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      const PetEditScreen(petId: '1'),
      _MutablePetNotifier(_state()),
    );
    await tester.pumpAndSettle();

    final profile = find.byKey(const Key('pet-edit-profile-section'));
    final dateField = find
        .descendant(of: profile, matching: find.byType(PetDateField))
        .first;

    await tester.ensureVisible(dateField);
    await tester.tap(dateField);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-date-year-wheel')), findsOneWidget);
  });

  testWidgets('pet text field focused border uses primary color', (
    tester,
  ) async {
    await _pump(
      tester,
      const PetEditScreen(petId: '1'),
      _MutablePetNotifier(_state()),
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    final focusedBorder =
        textField.decoration!.focusedBorder! as OutlineInputBorder;

    expect(focusedBorder.borderSide.color, AppColors.primary);
  });

  testWidgets('pet edit preserves hidden existing values in update payload', (
    tester,
  ) async {
    final notifier = _UpdatePetNotifier(
      _state(
        pets: [
          _pet(
            '1',
            weight: 4.2,
            animalRegistrationNumber: '410000000000001',
            neutered: true,
            diseases: '기관지염',
            specialNotes: '닭고기 알러지',
          ),
        ],
      ),
    );
    await _pump(tester, const PetEditScreen(petId: '1'), notifier);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pet-edit-save-button')), findsNothing);
    expect(find.text('수정 완료'), findsOneWidget);
    expect(find.text('색상'), findsNothing);

    await _tapSave(tester);

    expect(notifier.updatedPetId, '1');
    expect(notifier.updatedBody?['weight'], 4.2);
    expect(
      notifier.updatedBody?['animalRegistrationNumber'],
      '410000000000001',
    );
    expect(notifier.updatedBody?['neutered'], true);
    expect(notifier.updatedBody?['diseases'], '기관지염');
    expect(notifier.updatedBody?['specialNotes'], '닭고기 알러지');
    expect(notifier.updatedBody?['accentColor'], '#F4A460');
    expect(notifier.updatedBody?['bgLight'], '#FFF8F0');
  });

  testWidgets('male pet with existing null defaults neutered to incomplete', (
    tester,
  ) async {
    final notifier = _UpdatePetNotifier(
      _state(pets: [_pet('1', gender: 'male', neutered: null)]),
    );
    await _pump(tester, const PetEditScreen(petId: '1'), notifier);
    await tester.pumpAndSettle();

    final incomplete = _choiceInProfile(tester, '미완료');
    expect(incomplete.selected, isTrue);
    expect(incomplete.enabled, isTrue);

    await _tapSave(tester);
    expect(notifier.updatedBody?['neutered'], false);
  });

  testWidgets('male neutered selection is reflected in update payload', (
    tester,
  ) async {
    final notifier = _UpdatePetNotifier(
      _state(pets: [_pet('1', gender: 'male', neutered: null)]),
    );
    await _pump(tester, const PetEditScreen(petId: '1'), notifier);
    await tester.pumpAndSettle();

    await _tapChoiceInProfile(tester, '완료');
    await _tapSave(tester);

    expect(notifier.updatedBody?['neutered'], true);
  });

  testWidgets(
    'female or unspecified gender disables neutered and preserves existing value',
    (tester) async {
      final notifier = _UpdatePetNotifier(
        _state(pets: [_pet('1', gender: 'female', neutered: true)]),
      );
      await _pump(tester, const PetEditScreen(petId: '1'), notifier);
      await tester.pumpAndSettle();

      final complete = _choiceInProfile(tester, '완료');
      final incomplete = _choiceInProfile(tester, '미완료');
      expect(complete.selected, isTrue);
      expect(complete.enabled, isFalse);
      expect(incomplete.enabled, isFalse);

      await _tapSave(tester);
      expect(notifier.updatedBody?['neutered'], true);
    },
  );

  testWidgets(
    'unspecified gender with existing null keeps neutered absent from payload',
    (tester) async {
      final notifier = _UpdatePetNotifier(
        _state(pets: [_pet('1', gender: null, neutered: null)]),
      );
      await _pump(tester, const PetEditScreen(petId: '1'), notifier);
      await tester.pumpAndSettle();

      final complete = _choiceInProfile(tester, '완료');
      final incomplete = _choiceInProfile(tester, '미완료');
      expect(complete.selected, isFalse);
      expect(incomplete.selected, isFalse);
      expect(complete.enabled, isFalse);
      expect(incomplete.enabled, isFalse);

      await _tapSave(tester);
      expect(notifier.updatedBody, isNot(contains('neutered')));
    },
  );

  testWidgets(
    'switching from male edit to female preserves original neutered value',
    (tester) async {
      final notifier = _UpdatePetNotifier(
        _state(pets: [_pet('1', gender: 'male', neutered: false)]),
      );
      await _pump(tester, const PetEditScreen(petId: '1'), notifier);
      await tester.pumpAndSettle();

      await _tapChoiceInProfile(tester, '완료');
      await _tapChoiceInProfile(tester, '여아');
      await _tapSave(tester);

      expect(notifier.updatedBody?['gender'], 'female');
      expect(notifier.updatedBody?['neutered'], false);
    },
  );

  testWidgets('pet edit sends birthDateUnknown when user marks unknown', (
    tester,
  ) async {
    final notifier = _UpdatePetNotifier(_state());
    await _pump(tester, const PetEditScreen(petId: '1'), notifier);
    await tester.pumpAndSettle();

    final unknownButton = find.widgetWithText(TextButton, '생년월일을 몰라요');
    await tester.ensureVisible(unknownButton);
    await tester.tap(unknownButton);
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(notifier.updatedBody?['birthDateUnknown'], true);
    expect(notifier.updatedBody, isNot(contains('birthDate')));
  });

  testWidgets('pet edit rejects an empty name before sending request', (
    tester,
  ) async {
    final notifier = _UpdatePetNotifier(_state());
    await _pump(tester, const PetEditScreen(petId: '1'), notifier);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(PetTextField).first, ' ');
    await _tapSave(tester);

    expect(notifier.updatedBody, isNull);
    expect(find.text('반려동물 이름을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('pet edit saves selected diseases as comma string', (
    tester,
  ) async {
    final notifier = _UpdatePetNotifier(_state());
    await _pump(tester, const PetEditScreen(petId: '1'), notifier);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('질병'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('pet-edit-diseases-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복부'));
    await tester.tap(find.text('피부'));
    await tester.tap(find.widgetWithText(TextButton, '완료'));
    await tester.pumpAndSettle();

    await _tapSave(tester);

    expect(notifier.updatedBody?['diseases'], '복부, 피부');
  });

  testWidgets('pet edit success dialog blocks outside tap and back', (
    tester,
  ) async {
    final notifier = _UpdatePetNotifier(_state());
    await _pumpRouter(tester, '/pet/1/edit', notifier);

    await _tapSave(tester);

    expect(find.byType(PetConfirmDialog), findsOneWidget);
    expect(find.text('수정 완료'), findsWidgets);
    expect(find.text('Pet 1의 정보가 수정되었습니다.'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(PetConfirmDialog), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PetConfirmDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '확인'));
    await tester.pumpAndSettle();
    expect(find.byType(PetDetailScreen), findsOneWidget);
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

  testWidgets('last pet deletion uses PetConfirmDialog and stays put', (
    tester,
  ) async {
    final notifier = _DeletePetNotifier(_state());
    await _pumpRouter(tester, '/pet/1', notifier);

    await tester.scrollUntilVisible(
      find.text('삭제'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();

    expect(find.byType(PetConfirmDialog), findsOneWidget);
    expect(find.text('반려동물 삭제'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(notifier.deletedIds, ['1']);
    expect(find.text('반려동물을 찾을 수 없습니다'), findsOneWidget);
    expect(find.text('my-root'), findsNothing);
  });
}

Finder _inside(Finder parent, String text) =>
    find.descendant(of: parent, matching: find.text(text));

int _expandedChildCount(Row row) => row.children.whereType<Expanded>().length;

PetChoiceButton _choiceInProfile(WidgetTester tester, String label) {
  final profile = find.byKey(const Key('pet-edit-profile-section'));
  return tester
      .widgetList<PetChoiceButton>(
        find.descendant(of: profile, matching: find.byType(PetChoiceButton)),
      )
      .singleWhere((button) => button.label == label);
}

Future<void> _tapChoiceInProfile(WidgetTester tester, String label) async {
  final profile = find.byKey(const Key('pet-edit-profile-section'));
  final target = find.descendant(of: profile, matching: find.text(label));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, '수정 완료');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  PetNotifier notifier, {
  RecordService? recordService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => notifier),
        if (recordService != null)
          recordServiceProvider.overrideWithValue(recordService),
      ],
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

PetState _state({
  bool isLoading = false,
  List<Pet>? pets,
  String activePetId = '1',
}) => PetState(
  isLoading: isLoading,
  hasOnboarded: true,
  pets: pets ?? [_pet('1')],
  activePetId: activePetId,
  records: const [],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

Pet _pet(
  String id, {
  String? gender = 'female',
  double? weight,
  String? animalRegistrationNumber,
  bool? neutered,
  String? diseases,
  String? specialNotes,
}) => Pet(
  id: id,
  name: 'Pet $id',
  species: 'dog',
  birthDate: '2022-03-15',
  adoptionDate: '2022-04-01',
  accentColor: '#F4A460',
  bgLight: '#FFF8F0',
  gender: gender,
  weight: weight,
  animalRegistrationNumber: animalRegistrationNumber,
  neutered: neutered,
  diseases: diseases,
  specialNotes: specialNotes,
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

class _UpdatePetNotifier extends _MutablePetNotifier {
  _UpdatePetNotifier(super.initialState);

  String? updatedPetId;
  Map<String, dynamic>? updatedBody;

  @override
  Future<void> updatePet(
    String petId,
    Map<String, dynamic> body, {
    PetPhotoUpload? photo,
  }) async {
    updatedPetId = petId;
    updatedBody = body;
  }
}

ActivityRecord _weightRecord(
  String id,
  String petId,
  String date,
  String? time,
  Map<String, dynamic> detail,
) => ActivityRecord(
  id: id,
  petId: petId,
  typeId: 'weight',
  date: date,
  time: time,
  detail: detail,
);

class _RecordRequest {
  final String petId;
  final String? typeId;
  final int? limit;

  const _RecordRequest({
    required this.petId,
    required this.typeId,
    required this.limit,
  });
}

class _FakeRecordService extends RecordService {
  final Map<String, List<ActivityRecord>> recordsByPetId;
  final requests = <_RecordRequest>[];

  _FakeRecordService(this.recordsByPetId);

  @override
  Future<List<ActivityRecord>> getRecords(
    String petId, {
    String? date,
    String? typeId,
    int? limit,
  }) async {
    requests.add(_RecordRequest(petId: petId, typeId: typeId, limit: limit));
    return recordsByPetId[petId] ?? const [];
  }
}
