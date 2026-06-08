import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/records/meal_record_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('meal record screen shows approved full screen structure', (
    tester,
  ) async {
    await _pumpMealRoute(tester);

    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.byType(AppFormHeader), findsOneWidget);
    expect(find.text('급식 기록'), findsOneWidget);
    expect(find.text('등록'), findsOneWidget);
    expect(find.text('날짜/시간'), findsOneWidget);
    expect(find.byKey(const Key('meal-date-label')), findsOneWidget);
    expect(find.byKey(const Key('meal-date-button')), findsNothing);
    expect(find.byKey(const Key('meal-time-button')), findsOneWidget);
    expect(find.text('현재 시간으로 설정'), findsOneWidget);
    expect(find.text('사료 종류'), findsOneWidget);
    expect(find.text('상세 정보'), findsOneWidget);
    expect(find.text('메모'), findsOneWidget);
    expect(find.byKey(const Key('meal-note-field')), findsWidgets);
    expect(find.text('추가 정보 (브랜드/급식방법) 펼치기'), findsOneWidget);
    expect(find.text('선택 입력'), findsNothing);
    expect(find.text('사진 추가 (0/1)'), findsOneWidget);
    expect(find.text('브랜드명'), findsNothing);
    expect(find.text('급식 방법'), findsNothing);
  });

  testWidgets('meal screen shows food and consumption emoji card options', (
    tester,
  ) async {
    await _pumpMealRoute(tester);

    for (final label in ['습식', '건식', '간식', '처방식', '생식', '동결건조']) {
      expect(find.text(label), findsOneWidget);
    }

    for (final emoji in [
      '🥫',
      '🍚',
      '🦴',
      '💊',
      '🥩',
      '❄️',
      '😭',
      '😐',
      '🙂',
      '🥰',
    ]) {
      expect(find.text(emoji), findsOneWidget);
    }

    for (final label in ['25%', '50%', '75%', '100%']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('save stays disabled until required meal fields are filled', (
    tester,
  ) async {
    final notifier = _MealTestPetNotifier();
    await _pumpMealRoute(tester, notifier: notifier);

    await _tapSave(tester);
    expect(notifier.savedBodies, isEmpty);

    await tester.tap(find.byKey(const Key('meal-food-type-wet')));
    await _enterRecordNumber(tester, const Key('meal-served-amount-field'), [
      '3',
      '5',
    ]);
    await tester.tap(find.byKey(const Key('meal-consumed-75')));
    await tester.pump();

    await _tapSave(tester);
    expect(notifier.savedBodies, hasLength(1));
  });

  testWidgets('additional info expands optional fields', (tester) async {
    await _pumpMealRoute(tester);

    await tester.tap(find.byKey(const Key('meal-more-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('선택 입력'), findsOneWidget);
    expect(find.text('브랜드명'), findsOneWidget);
    expect(find.text('급식 방법'), findsOneWidget);
    expect(find.text('배식'), findsOneWidget);
    expect(find.text('자율급식'), findsOneWidget);
    expect(find.text('자동급식기'), findsOneWidget);
    expect(find.byKey(const Key('meal-note-field')), findsWidgets);
  });

  testWidgets('photo picker callback updates selected photo label', (
    tester,
  ) async {
    await _pumpMealScreen(
      tester,
      pickImage: () async => XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'meal-photo.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    await tester.tap(find.byKey(const Key('meal-photo-button')));
    await tester.pump();

    expect(find.text('사진 추가 (1/1) · meal-photo.jpg'), findsOneWidget);
  });

  testWidgets('save builds backend compatible meal payload', (tester) async {
    final notifier = _MealTestPetNotifier();
    await _pumpMealRoute(tester, notifier: notifier);

    await tester.tap(find.byKey(const Key('meal-food-type-wet')));
    await tester.enterText(find.byKey(const Key('meal-product-field')), '치킨캔');
    await _enterRecordNumber(tester, const Key('meal-served-amount-field'), [
      '3',
      '5',
    ]);
    await tester.tap(find.byKey(const Key('meal-consumed-75')));
    await tester.enterText(find.byKey(const Key('meal-note-field')), '메모');
    await tester.tap(find.byKey(const Key('meal-more-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('meal-brand-field')), '브랜드명');
    await tester.tap(find.byKey(const Key('meal-feeding-method-served')));
    await _tapSave(tester);

    expect(notifier.savedBodies, hasLength(1));
    expect(notifier.savedBodies.single, {
      'typeId': 'meal',
      'date': notifier.savedBodies.single['date'],
      'time': notifier.savedBodies.single['time'],
      'note': '메모',
      'detail': {
        'foodType': 'wet',
        'product': '치킨캔',
        'servedAmount': 35,
        'consumedPercent': 75,
        'brand': '브랜드명',
        'feedingMethod': 'served',
      },
    });
    expect(
      notifier.savedBodies.single['date'],
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
    );
    expect(
      notifier.savedBodies.single['time'],
      matches(RegExp(r'^\d{2}:\d{2}$')),
    );
  });

  testWidgets('meal date is read-only and time button opens picker sheet', (
    tester,
  ) async {
    await _pumpMealRoute(tester);

    expect(find.byKey(const Key('meal-date-label')), findsOneWidget);
    expect(find.byKey(const Key('meal-date-button')), findsNothing);

    await tester.tap(find.byKey(const Key('meal-time-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-time-period-wheel')), findsOneWidget);
  });

  testWidgets('meal route date is saved after setting current time', (
    tester,
  ) async {
    final notifier = _MealTestPetNotifier();
    await _pumpMealRoute(
      tester,
      notifier: notifier,
      initialLocation: '/records/meal/new?date=2026-05-09',
    );

    expect(find.text('2026-05-09'), findsOneWidget);
    await tester.tap(find.byKey(const Key('meal-set-now-button')));
    await tester.pump();
    expect(find.text('2026-05-09'), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal-food-type-wet')));
    await _enterRecordNumber(tester, const Key('meal-served-amount-field'), [
      '3',
      '5',
    ]);
    await tester.tap(find.byKey(const Key('meal-consumed-75')));
    await tester.pump();
    await _tapSave(tester);

    expect(notifier.savedBodies.single['date'], '2026-05-09');
  });

  testWidgets('meal save button is a single bottom content CTA', (
    tester,
  ) async {
    await _pumpMealRoute(tester);

    final saveButton = find.byKey(const Key('meal-save-button'));
    expect(saveButton, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppFormHeader), matching: saveButton),
      findsNothing,
    );
  });

  testWidgets('meal save button is reached by scrolling long form content', (
    tester,
  ) async {
    await _pumpMealRoute(tester, physicalSize: const Size(800, 900));

    final scrollable = find.byType(Scrollable).first;
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.scrollUntilVisible(
      find.byKey(const Key('meal-save-button')),
      220,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.byKey(const Key('meal-save-button')));
    await tester.pumpAndSettle();
    final after = tester.state<ScrollableState>(scrollable).position.pixels;

    expect(after, greaterThan(before));
  });

  testWidgets('meal amount integer input ignores decimal key', (tester) async {
    await _pumpMealRoute(tester);

    await _enterRecordNumber(tester, const Key('meal-served-amount-field'), [
      '1',
      'dot',
      '2',
    ]);

    final field = tester.widget<TextField>(
      find.byKey(const Key('meal-served-amount-field')),
    );
    expect(field.controller!.text, '12');
  });

  testWidgets('meal edit initializes existing values and updates record', (
    tester,
  ) async {
    final notifier = _MealTestPetNotifier(
      records: const [
        ActivityRecord(
          id: 'meal-edit',
          petId: 'pet-1',
          typeId: 'meal',
          date: '2026-05-09',
          time: '09:10:32',
          note: '기존 메모',
          detail: {
            'foodType': 'snack',
            'product': '츄르',
            'servedAmount': 35,
            'consumedPercent': 75,
            'brand': '브랜드',
            'feedingMethod': 'served',
          },
        ),
      ],
    );
    await _pumpMealRoute(
      tester,
      notifier: notifier,
      initialLocation: '/records/meal-edit/edit',
    );

    expect(find.text('급식 수정'), findsOneWidget);
    expect(find.text('2026-05-09'), findsOneWidget);
    expect(find.text('09:10'), findsOneWidget);
    expect(find.byKey(const Key('meal-photo-button')), findsNothing);
    expect(find.text('등록된 사진이 없어요'), findsOneWidget);

    await _tapEditSave(tester);

    expect(notifier.updatedRecords.single.$1, 'meal-edit');
    expect(notifier.updatedRecords.single.$2['date'], '2026-05-09');
    expect(notifier.updatedRecords.single.$2['time'], '09:10');
    expect(notifier.updatedRecords.single.$2['detail'], {
      'foodType': 'snack',
      'product': '츄르',
      'servedAmount': 35,
      'consumedPercent': 75,
      'brand': '브랜드',
      'feedingMethod': 'served',
    });
  });
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('meal-save-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('meal-save-button')));
  await tester.pump();
}

Future<void> _tapEditSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('record-edit-save-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('record-edit-save-button')));
  await tester.pump();
}

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

Future<void> _pumpMealRoute(
  WidgetTester tester, {
  _MealTestPetNotifier? notifier,
  Size physicalSize = const Size(800, 2200),
  String initialLocation = '/records/meal/new',
}) async {
  tester.view.physicalSize = physicalSize;
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
        petProvider.overrideWith((ref) => notifier ?? _MealTestPetNotifier()),
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

Future<void> _pumpMealScreen(
  WidgetTester tester, {
  Future<XFile?> Function()? pickImage,
  _MealTestPetNotifier? notifier,
}) async {
  tester.view.physicalSize = const Size(800, 2200);
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
        petProvider.overrideWith((ref) => notifier ?? _MealTestPetNotifier()),
      ],
      child: MaterialApp(home: MealRecordScreen(pickImageForTest: pickImage)),
    ),
  );
  await tester.pumpAndSettle();
}

class _MealTestPetNotifier extends PetNotifier {
  _MealTestPetNotifier({List<ActivityRecord> records = const []})
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
          records: records,
          routines: const [],
          todayRoutineItems: const [],
          routineCompletions: const {},
          quickTypeIds: const [],
        ),
      );

  final savedBodies = <Map<String, dynamic>>[];
  final updatedRecords = <(String, Map<String, dynamic>)>[];

  @override
  Future<void> addRecord(
    Map<String, dynamic> body, {
    RecordPhotoUpload? photo,
  }) async {
    savedBodies.add(body);
  }

  @override
  Future<void> updateRecord(String recordId, Map<String, dynamic> body) async {
    updatedRecords.add((recordId, body));
  }
}
