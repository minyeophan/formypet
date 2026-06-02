import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('poop form starts with stool status and color grids', (
    tester,
  ) async {
    await _pumpCategoryRoute(tester, '/records/poop/new');

    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.byType(AppFormHeader), findsOneWidget);
    expect(find.text('배변 기록'), findsOneWidget);
    expect(find.text('날짜/시간'), findsOneWidget);
    expect(find.text('종류'), findsOneWidget);
    expect(find.text('대변'), findsOneWidget);
    expect(find.text('소변'), findsOneWidget);
    expect(find.text('변 상태'), findsOneWidget);
    expect(find.text('보통 변'), findsOneWidget);
    expect(find.text('묽은 변'), findsOneWidget);
    expect(find.text('설사'), findsOneWidget);
    expect(find.text('색상'), findsOneWidget);

    for (final label in ['갈색', '연갈색', '붉은색', '검은색', '녹색', '기타']) {
      expect(find.text(label), findsOneWidget);
    }

    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('urine hides stool status and shows urine colors', (
    tester,
  ) async {
    await _pumpCategoryRoute(tester, '/records/poop/new');

    await tester.tap(find.byKey(const Key('category-poop-kind-urine')));
    await tester.pump();

    expect(find.text('변 상태'), findsNothing);
    for (final label in ['투명', '연노랑', '노랑', '진노랑', '붉은색', '갈색']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('poop warning appears for risky stool or urine selections', (
    tester,
  ) async {
    await _pumpCategoryRoute(tester, '/records/poop/new');

    await tester.tap(find.byKey(const Key('category-poop-shape-loose')));
    await tester.pump();

    expect(find.textContaining('수의사 상담'), findsOneWidget);

    await tester.tap(find.byKey(const Key('category-poop-kind-urine')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-poop-color-darkYellow')));
    await tester.pump();

    expect(find.textContaining('수의사 상담'), findsOneWidget);
  });

  testWidgets('poop form saves stool backend compatible payload', (
    tester,
  ) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(tester, '/records/poop/new', notifier: notifier);

    await tester.tap(find.byKey(const Key('category-poop-shape-normal')));
    await tester.tap(find.byKey(const Key('category-poop-color-brown')));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();

    expect(notifier.savedBodies.single, {
      'typeId': 'poop',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'detail': {'poopShape': 'normal', 'poopColor': 'brown'},
    });
  });

  testWidgets('poop form saves optional note payload', (tester) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(tester, '/records/poop/new', notifier: notifier);

    await tester.tap(find.byKey(const Key('category-poop-shape-normal')));
    await tester.tap(find.byKey(const Key('category-poop-color-brown')));
    await tester.enterText(
      find.byKey(const Key('category-note-field')),
      '산책 후',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();

    expect(notifier.savedBodies.single, {
      'typeId': 'poop',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'note': '산책 후',
      'detail': {'poopShape': 'normal', 'poopColor': 'brown'},
    });
  });

  testWidgets('poop form saves urine backend compatible payload', (
    tester,
  ) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(tester, '/records/poop/new', notifier: notifier);

    await tester.tap(find.byKey(const Key('category-poop-kind-urine')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-poop-color-yellow')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();

    expect(notifier.savedBodies.single, {
      'typeId': 'poop',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'detail': {'poopShape': 'urine', 'poopColor': 'yellow'},
    });
  });

  testWidgets('walk form only shows distance and memo fields', (tester) async {
    await _pumpCategoryRoute(tester, '/records/walk/new');

    expect(find.text('산책 기록'), findsOneWidget);
    expect(find.text('거리'), findsOneWidget);
    expect(find.text('산책 메모'), findsOneWidget);
    expect(find.text('병원명'), findsNothing);
    expect(find.text('몸무게'), findsNothing);
  });

  testWidgets('walk form saves decimal distance payload', (tester) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(tester, '/records/walk/new', notifier: notifier);
    await _enterRecordNumber(tester, const Key('category-distance-field'), [
      '1',
      'dot',
      '2',
      '3',
    ]);
    await tester.enterText(
      find.byKey(const Key('category-note-field')),
      '공원 한 바퀴',
    );
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();
    expect(notifier.savedBodies.single, {
      'typeId': 'walk',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'note': '공원 한 바퀴',
      'detail': {'distance': 1.23},
    });
  });

  testWidgets('water form saves amount payload with fixed ml UI unit', (
    tester,
  ) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(tester, '/records/water/new', notifier: notifier);

    expect(find.text('음수 기록'), findsOneWidget);
    expect(find.text('음수량'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await _enterRecordNumber(tester, const Key('category-water-amount-field'), [
      '2',
      '5',
      '0',
    ]);
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();

    expect(notifier.savedBodies.single, {
      'typeId': 'water',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'detail': {'amount': 250.0},
    });
  });

  testWidgets('diary form saves note-only payload', (tester) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(tester, '/records/diary/new', notifier: notifier);

    expect(find.text('일기 기록'), findsOneWidget);
    expect(find.text('메모'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('category-diary-note-field')),
      '오늘은 컨디션이 좋았다.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();

    expect(notifier.savedBodies.single, {
      'typeId': 'diary',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'note': '오늘은 컨디션이 좋았다.',
    });
  });

  testWidgets('weight form saves decimal weight payload', (tester) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(tester, '/records/weight/new', notifier: notifier);
    expect(find.text('최근 기록'), findsOneWidget);
    expect(find.text('히스토리'), findsNothing);
    expect(find.text('기록'), findsNothing);
    expect(find.text('저장하면 이곳에 기록이 쌓여요.'), findsNothing);
    await _enterRecordNumber(tester, const Key('category-weight-field'), [
      '4',
      'dot',
      '6',
    ]);
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();
    expect(notifier.savedBodies.single, {
      'typeId': 'weight',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'detail': {'weight': 4.6},
    });
  });

  testWidgets('vet form saves backend compatible payload', (tester) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(tester, '/records/vet/new', notifier: notifier);
    await tester.enterText(
      find.byKey(const Key('category-vet-clinic-field')),
      '튼튼동물병원',
    );
    await tester.enterText(
      find.byKey(const Key('category-vet-reason-field')),
      '정기 검진',
    );
    await tester.enterText(
      find.byKey(const Key('category-vet-treatment-field')),
      '이상 없음',
    );
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();
    expect(notifier.savedBodies.single, {
      'typeId': 'vet',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'detail': {
        'vetClinicName': '튼튼동물병원',
        'vetVisitReason': '정기 검진',
        'vetTreatment': '이상 없음',
      },
    });
  });

  testWidgets('medicine form saves backend compatible payload', (tester) async {
    final notifier = _CategoryTestPetNotifier();
    await _pumpCategoryRoute(
      tester,
      '/records/medicine/new',
      notifier: notifier,
    );
    await tester.enterText(
      find.byKey(const Key('category-medicine-name-field')),
      '오메가3',
    );
    await tester.enterText(
      find.byKey(const Key('category-dosage-field')),
      '1정',
    );
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pump();
    expect(notifier.savedBodies.single, {
      'typeId': 'medicine',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'detail': {'medicineName': '오메가3', 'dosage': '1정'},
    });
  });

  testWidgets('date and time buttons open common picker sheets', (
    tester,
  ) async {
    await _pumpCategoryRoute(tester, '/records/walk/new');

    await tester.tap(find.byKey(const Key('category-date-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-date-year-wheel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('record-picker-cancel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('category-time-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-time-period-wheel')), findsOneWidget);
  });
}

TextButton _saveButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.byKey(const Key('category-save-button')));

Future<void> _enterRecordNumber(
  WidgetTester tester,
  Key fieldKey,
  List<String> keys,
) async {
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  for (final key in keys) {
    await tester.tap(find.byKey(Key('record-number-key-$key')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('record-picker-done')));
  await tester.pumpAndSettle();
}

Future<void> _pumpCategoryRoute(
  WidgetTester tester,
  String initialLocation, {
  _CategoryTestPetNotifier? notifier,
}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.test(
            const AuthState(isLoading: false, isAuthenticated: true),
          ),
        ),
        petProvider.overrideWith(
          (ref) => notifier ?? _CategoryTestPetNotifier(),
        ),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final router = ref.watch(routerProvider);
          if (router.routeInformationProvider.value.uri.toString() !=
              initialLocation) {
            router.go(initialLocation);
          }
          return MaterialApp.router(routerConfig: router);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _CategoryTestPetNotifier extends PetNotifier {
  _CategoryTestPetNotifier()
    : super.test(
        PetState(
          isLoading: false,
          hasOnboarded: true,
          pets: const [
            Pet(
              id: 'pet-1',
              name: '몽실이',
              species: 'dog',
              birthDate: '2022-03-15',
              accentColor: '#F4A460',
              bgLight: '#FFF8F0',
            ),
          ],
          activePetId: 'pet-1',
          records: const [
            ActivityRecord(
              id: 'weight-1',
              petId: 'pet-1',
              typeId: 'weight',
              date: '2026-05-21',
              time: '09:00',
              detail: {'weight': 4.5},
            ),
          ],
          routines: const [],
          todayRoutineItems: const [],
          routineCompletions: const {},
          quickTypeIds: const [],
        ),
      );

  final savedBodies = <Map<String, dynamic>>[];

  @override
  Future<void> addRecord(
    Map<String, dynamic> body, {
    RecordPhotoUpload? photo,
  }) async {
    savedBodies.add(body);
  }
}
