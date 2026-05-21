import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('meal record screen shows approved full screen structure', (
    tester,
  ) async {
    await _pumpMealRoute(tester);

    expect(find.text('뒤로'), findsOneWidget);
    expect(find.text('급식 기록'), findsOneWidget);
    expect(find.text('등록'), findsOneWidget);
    expect(find.text('날짜/시간'), findsOneWidget);
    expect(find.text('사료 종류'), findsOneWidget);
    expect(find.text('상세 정보'), findsOneWidget);
    expect(find.text('추가 정보'), findsOneWidget);
    expect(find.text('사진 추가 (0/1)'), findsOneWidget);
    expect(find.text('브랜드명'), findsNothing);
  });

  testWidgets('save stays disabled until required meal fields are filled', (
    tester,
  ) async {
    await _pumpMealRoute(tester);

    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('meal-food-type-wet')));
    await tester.enterText(
      find.byKey(const Key('meal-served-amount-field')),
      '35',
    );
    await tester.tap(find.byKey(const Key('meal-consumed-75')));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('additional info expands optional fields', (tester) async {
    await _pumpMealRoute(tester);

    await tester.tap(find.byKey(const Key('meal-more-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('브랜드명'), findsOneWidget);
    expect(find.text('급식 방법'), findsOneWidget);
    expect(find.text('메모'), findsOneWidget);
  });

  testWidgets('save builds backend compatible meal payload', (tester) async {
    final notifier = _MealTestPetNotifier();
    await _pumpMealRoute(tester, notifier: notifier);

    await tester.tap(find.byKey(const Key('meal-food-type-wet')));
    await tester.enterText(find.byKey(const Key('meal-product-field')), '치킨캔');
    await tester.enterText(
      find.byKey(const Key('meal-served-amount-field')),
      '35',
    );
    await tester.tap(find.byKey(const Key('meal-consumed-75')));
    await tester.tap(find.byKey(const Key('meal-more-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('meal-brand-field')), '브랜드명');
    await tester.tap(find.byKey(const Key('meal-feeding-method-served')));
    await tester.enterText(find.byKey(const Key('meal-note-field')), '메모');
    await tester.tap(find.byKey(const Key('meal-save-button')));
    await tester.pump();

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
}

TextButton _saveButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.byKey(const Key('meal-save-button')));

Future<void> _pumpMealRoute(
  WidgetTester tester, {
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
      child: Consumer(
        builder: (context, ref, child) {
          final router = ref.watch(routerProvider);
          if (router.routeInformationProvider.value.uri.toString() !=
              '/records/meal/new') {
            router.go('/records/meal/new');
          }
          return MaterialApp.router(routerConfig: router);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MealTestPetNotifier extends PetNotifier {
  _MealTestPetNotifier()
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
          records: const [],
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
