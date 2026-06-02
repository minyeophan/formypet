import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/records/expense_add_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('expense add screen shows supported fields only', (tester) async {
    final notifier = _TrackingPetNotifier(_state());
    await _pumpScreen(tester, notifier);

    for (final label in [
      '비용 추가',
      '금액',
      '카테고리',
      '날짜/시간',
      '반려동물',
      '제품이름',
      '구매처 URL',
      '사진',
      '메모',
      '비용 저장',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(find.text('몽실이'), findsOneWidget);
    expect(find.text('스마트 입력'), findsNothing);
    expect(find.text('영수증 스캔'), findsNothing);
    expect(find.text('결제 문자'), findsNothing);
    expect(find.text('+ 카테고리'), findsNothing);
    expect(notifier.addRecordCalls, 0);
    expect(find.byType(AppFormHeader), findsOneWidget);
  });

  testWidgets('save button becomes emphasized after amount and category', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state());
    await _pumpScreen(tester, notifier);

    expect(_saveButtonColor(tester), AppColors.surfaceSoft);

    await tester.tap(find.byKey(const Key('expense-amount-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-number-key-1')));
    await tester.tap(find.byKey(const Key('record-number-key-2')));
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();

    expect(_saveButtonColor(tester), AppColors.surfaceSoft);

    await tester.tap(find.byKey(const Key('expense-category-snack')));
    await tester.pumpAndSettle();

    expect(_saveButtonColor(tester), AppColors.text);
  });

  testWidgets('save shows preparing toast without adding a provider record', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state());
    await _pumpScreen(tester, notifier);

    await tester.tap(find.byKey(const Key('expense-amount-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-number-key-5')));
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-category-food')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pump();

    expect(find.text('준비중'), findsOneWidget);
    expect(notifier.addRecordCalls, 0);
  });

  testWidgets('expense add screen guides when no active pet exists', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state(activePetId: null));
    await _pumpScreen(tester, notifier);

    expect(find.text('반려동물을 등록해 주세요.'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _TrackingPetNotifier notifier,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(home: ExpenseAddScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Color _saveButtonColor(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byKey(const Key('expense-save-button')),
      matching: find.byType(AnimatedContainer),
    ),
  );
  final decoration = container.decoration! as BoxDecoration;
  return decoration.color!;
}

PetState _state({String? activePetId = 'pet-1'}) => PetState(
  isLoading: false,
  hasOnboarded: activePetId != null,
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
  activePetId: activePetId,
  records: const [],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

class _TrackingPetNotifier extends PetNotifier {
  int addRecordCalls = 0;

  _TrackingPetNotifier(super.initialState) : super.test();

  @override
  Future<void> addRecord(
    Map<String, dynamic> body, {
    RecordPhotoUpload? photo,
  }) async {
    addRecordCalls += 1;
  }
}
