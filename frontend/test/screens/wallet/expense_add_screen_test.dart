import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/wallet/expense_add_screen.dart';
import 'package:frontend/screens/wallet/expense_detail_screen.dart';
import 'package:frontend/screens/wallet/expense_edit_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('expense add screen shows supported fields only', (tester) async {
    final notifier = _TrackingPetNotifier(_state());
    await _pumpScreen(tester, notifier, const ExpenseAddScreen());

    for (final label in [
      '비용 추가',
      '금액',
      '카테고리',
      '날짜/시간',
      '반려동물',
      '항목명',
      '메모',
      '비용 저장',
      '기타',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    expect(find.text('몽실이'), findsOneWidget);
    expect(find.text('사진'), findsNothing);
    expect(find.text('영수증'), findsNothing);
    expect(find.text('+ 항목 추가'), findsNothing);
    expect(find.text('+ 사진'), findsNothing);
    expect(notifier.addRecordCalls, 0);
  });

  testWidgets('canSubmit false keeps save tap from calling addRecord', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state());
    await _pumpScreen(tester, notifier, const ExpenseAddScreen());

    expect(_saveButtonColor(tester), AppColors.surfaceSoft);
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pump();

    expect(notifier.addRecordCalls, 0);
  });

  testWidgets('expense add saves payload without empty or legacy web fields', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state());
    await _pumpExpenseRouter(tester, notifier, '/wallet/expenses/new');

    await _enterAmount(tester, '12000');
    await tester.tap(find.byKey(const Key('expense-category-food')));
    await tester.enterText(
      find.byKey(const Key('expense-item-name-field')),
      ' 사료 ',
    );
    await tester.enterText(find.byKey(const Key('expense-memo-field')), '  ');
    await tester.pumpAndSettle();

    expect(_saveButtonColor(tester), AppColors.text);
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('wallet-home'), findsOneWidget);
    expect(notifier.addRecordCalls, 1);
    expect(notifier.lastAddRecordBody?['typeId'], 'expense');
    expect(notifier.lastAddRecordBody?['detail']['amount'], 12000);
    expect(notifier.lastAddRecordBody?['detail']['currency'], 'KRW');
    expect(notifier.lastAddRecordBody?['detail']['category'], 'food');
    expect(notifier.lastAddRecordBody?['detail']['itemName'], '사료');
    expect(notifier.lastAddRecordBody?.containsKey('note'), isFalse);
    expect(
      notifier.lastAddRecordBody?['detail'].containsKey(_legacyWebFieldKey),
      isFalse,
    );
    expect(notifier.lastAddRecordBody?['detail'].containsKey('url'), isFalse);
  });

  testWidgets('expense add guides and blocks save when no active pet exists', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state(activePetId: null));
    await _pumpScreen(tester, notifier, const ExpenseAddScreen());

    expect(find.text('반려동물을 등록해 주세요'), findsOneWidget);
    await _enterAmount(tester, '5000');
    await tester.tap(find.byKey(const Key('expense-category-snack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-save-button')));

    expect(notifier.addRecordCalls, 0);
  });

  testWidgets('expense add failure shows inline error and unlocks submit', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state())..failAdd = true;
    await _pumpScreen(tester, notifier, const ExpenseAddScreen());

    await _enterAmount(tester, '7000');
    await tester.tap(find.byKey(const Key('expense-category-snack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expense-form-error')), findsOneWidget);
    expect(_saveButtonColor(tester), AppColors.text);
  });

  testWidgets(
    'expense detail shows read-only fields and hides optional empty rows',
    (tester) async {
      final notifier = _TrackingPetNotifier(
        _state(records: [_expenseRecord()]),
      );
      await _pumpScreen(
        tester,
        notifier,
        const ExpenseDetailScreen(recordId: 'expense-1'),
      );

      expect(find.text('지출 상세'), findsOneWidget);
      expect(find.text('12,000원'), findsOneWidget);
      expect(find.text('간식'), findsOneWidget);
      expect(find.text('2026-05-09'), findsOneWidget);
      expect(find.text('09:10'), findsOneWidget);
      expect(find.text('사진'), findsNothing);
      expect(find.text('영수증'), findsNothing);
    },
  );

  testWidgets(
    'expense edit initializes values and drops legacy web keys on update',
    (tester) async {
      final notifier = _TrackingPetNotifier(
        _state(records: [_expenseRecord()]),
      );
      await _pumpExpenseRouter(
        tester,
        notifier,
        '/wallet/expenses/expense-1/edit',
      );

      expect(find.text('지출 수정'), findsOneWidget);
      expect(find.text('09:10'), findsOneWidget);
      expect(find.text('기존 항목'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('expense-memo-field')),
        '수정 메모',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('expense-detail-expense-1'), findsOneWidget);
      expect(notifier.lastUpdateRecordId, 'expense-1');
      expect(notifier.lastUpdateRecordBody?['time'], '09:10');
      expect(notifier.lastUpdateRecordBody?['detail']['amount'], 12000);
      expect(notifier.lastUpdateRecordBody?['detail']['category'], 'snack');
      expect(notifier.lastUpdateRecordBody?['note'], '수정 메모');
      expect(
        notifier.lastUpdateRecordBody?['detail'].containsKey(
          _legacyWebFieldKey,
        ),
        isFalse,
      );
    },
  );

  testWidgets('expense edit failure shows inline error and unlocks submit', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state(records: [_expenseRecord()]))
      ..failUpdate = true;
    await _pumpScreen(
      tester,
      notifier,
      const ExpenseEditScreen(recordId: 'expense-1'),
    );

    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expense-form-error')), findsOneWidget);
    expect(_saveButtonColor(tester), AppColors.text);
  });

  testWidgets(
    'expense detail delete confirms, calls provider, and navigates wallet',
    (tester) async {
      final notifier = _TrackingPetNotifier(
        _state(records: [_expenseRecord()]),
      );
      await _pumpExpenseRouter(tester, notifier, '/wallet/expenses/expense-1');

      await tester.tap(find.byKey(const Key('expense-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense-delete-confirm-button')));
      await tester.pumpAndSettle();

      expect(notifier.deletedRecordId, 'expense-1');
      expect(find.text('wallet-home'), findsOneWidget);
    },
  );

  testWidgets('expense detail delete failure shows inline error', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(_state(records: [_expenseRecord()]))
      ..failDelete = true;
    await _pumpScreen(
      tester,
      notifier,
      const ExpenseDetailScreen(recordId: 'expense-1'),
    );

    await tester.tap(find.byKey(const Key('expense-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-delete-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expense-delete-error')), findsOneWidget);
  });

  testWidgets('missing or non-expense record shows wallet fallback state', (
    tester,
  ) async {
    final notifier = _TrackingPetNotifier(
      _state(
        records: const [
          ActivityRecord(
            id: 'meal-1',
            petId: 'pet-1',
            typeId: 'meal',
            date: '2026-05-09',
          ),
        ],
      ),
    );
    await _pumpScreen(
      tester,
      notifier,
      const ExpenseDetailScreen(recordId: 'meal-1'),
    );

    expect(find.text('지출 기록을 찾을 수 없어요'), findsOneWidget);
    expect(
      find.byKey(const Key('expense-not-found-wallet-button')),
      findsOneWidget,
    );
  });
}

Future<void> _enterAmount(WidgetTester tester, String digits) async {
  await tester.tap(find.byKey(const Key('expense-amount-input')));
  await tester.pumpAndSettle();
  for (final digit in digits.split('')) {
    await tester.tap(find.byKey(Key('record-number-key-$digit')));
  }
  await tester.tap(find.byKey(const Key('record-picker-done')));
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _TrackingPetNotifier notifier,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpExpenseRouter(
  WidgetTester tester,
  _TrackingPetNotifier notifier,
  String initialLocation,
) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/wallet', builder: (_, _) => const Text('wallet-home')),
      GoRoute(
        path: '/wallet/expenses/new',
        builder: (_, _) => const ExpenseAddScreen(),
      ),
      GoRoute(
        path: '/wallet/expenses/:recordId',
        builder: (_, state) =>
            Text('expense-detail-${state.pathParameters['recordId']!}'),
      ),
      GoRoute(
        path: '/wallet/expenses/:recordId/edit',
        builder: (_, state) =>
            ExpenseEditScreen(recordId: state.pathParameters['recordId']!),
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

PetState _state({
  String? activePetId = 'pet-1',
  List<ActivityRecord> records = const [],
}) => PetState(
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
  records: records,
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

ActivityRecord _expenseRecord() => ActivityRecord(
  id: 'expense-1',
  petId: 'pet-1',
  typeId: 'expense',
  date: '2026-05-09',
  time: '09:10:32',
  detail: {
    'amount': 12000,
    'category': 'snack',
    'itemName': '기존 항목',
    _legacyWebFieldKey: 'legacy',
  },
);

String get _legacyWebFieldKey =>
    'purchase'
    'Url';

class _TrackingPetNotifier extends PetNotifier {
  int addRecordCalls = 0;
  Map<String, dynamic>? lastAddRecordBody;
  String? lastUpdateRecordId;
  Map<String, dynamic>? lastUpdateRecordBody;
  String? deletedRecordId;
  bool failAdd = false;
  bool failUpdate = false;
  bool failDelete = false;

  _TrackingPetNotifier(super.initialState) : super.test();

  @override
  Future<void> addRecord(
    Map<String, dynamic> body, {
    RecordPhotoUpload? photo,
  }) async {
    addRecordCalls += 1;
    lastAddRecordBody = body;
    if (failAdd) {
      throw StateError('add failed');
    }
  }

  @override
  Future<void> updateRecord(String recordId, Map<String, dynamic> body) async {
    lastUpdateRecordId = recordId;
    lastUpdateRecordBody = body;
    if (failUpdate) {
      throw StateError('update failed');
    }
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    deletedRecordId = recordId;
    if (failDelete) {
      throw StateError('delete failed');
    }
  }
}
