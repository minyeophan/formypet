import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/wallet_expense.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/screens/wallet/expense_add_screen.dart';
import 'package:frontend/screens/wallet/expense_detail_screen.dart';
import 'package:frontend/screens/wallet/expense_edit_screen.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('expense add saves wallet payload', (tester) async {
    final wallet = _TrackingWalletNotifier([_expense()]);
    await _pumpExpenseRouter(tester, wallet, '/wallet/expenses/new');

    await _enterAmount(tester, '12000');
    await tester.tap(find.byKey(const Key('expense-category-food')));
    await tester.enterText(
      find.byKey(const Key('expense-item-name-field')),
      ' snack ',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('wallet-home'), findsOneWidget);
    expect(wallet.createdPetId, 'pet-1');
    expect(wallet.createdBody?['amount'], 12000);
    expect(wallet.createdBody?['currency'], 'KRW');
    expect(wallet.createdBody?['category'], 'food');
    expect(wallet.createdBody?['itemName'], 'snack');
    expect(wallet.createdBody?.containsKey('typeId'), isFalse);
    expect(wallet.createdBody?.containsKey('detail'), isFalse);
  });

  testWidgets('expense edit sends nullable wallet body', (tester) async {
    final wallet = _TrackingWalletNotifier([_expense()]);
    await _pumpExpenseRouter(tester, wallet, '/wallet/expenses/expense-1/edit');

    expect(find.text('\uC9C0\uCD9C \uC218\uC815'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('expense-item-name-field')),
      '',
    );
    await tester.enterText(find.byKey(const Key('expense-memo-field')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expense-delete-button')), findsOneWidget);
    expect(wallet.updatedExpenseId, 'expense-1');
    expect(wallet.updatedBody?['itemName'], isNull);
    expect(wallet.updatedBody?['note'], isNull);
    expect(wallet.updatedBody?.containsKey('typeId'), isFalse);
    expect(wallet.updatedBody?.containsKey('detail'), isFalse);
  });

  testWidgets('expense detail deletes through wallet provider', (tester) async {
    final wallet = _TrackingWalletNotifier([_expense()]);
    await _pumpExpenseRouter(tester, wallet, '/wallet/expenses/expense-1');

    await tester.tap(find.byKey(const Key('expense-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-delete-confirm-button')));
    await tester.pumpAndSettle();

    expect(wallet.deletedExpenseId, 'expense-1');
    expect(find.text('wallet-home'), findsOneWidget);
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

Future<void> _pumpExpenseRouter(
  WidgetTester tester,
  _TrackingWalletNotifier wallet,
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
        path: '/wallet/expenses/:expenseId',
        builder: (_, state) =>
            ExpenseDetailScreen(expenseId: state.pathParameters['expenseId']!),
      ),
      GoRoute(
        path: '/wallet/expenses/:expenseId/edit',
        builder: (_, state) =>
            ExpenseEditScreen(expenseId: state.pathParameters['expenseId']!),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => PetNotifier.test(_petState())),
        walletExpenseProvider.overrideWith((ref) => wallet),
      ],
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
      id: 'pet-1',
      name: 'Mochi',
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
);

WalletExpense _expense({String id = 'expense-1'}) => WalletExpense(
  id: id,
  petId: 'pet-1',
  expenseDate: '2026-05-09',
  expenseTime: '09:10:32',
  amount: 12000,
  currency: 'KRW',
  category: 'snack',
  categoryLabel: '\uAC04\uC2DD',
  itemName: 'old item',
  note: 'old note',
);

class _TrackingWalletNotifier extends WalletExpenseNotifier {
  String? createdPetId;
  Map<String, dynamic>? createdBody;
  String? updatedExpenseId;
  Map<String, dynamic>? updatedBody;
  String? deletedExpenseId;

  _TrackingWalletNotifier(List<WalletExpense> items)
    : super(_NoopWalletExpenseService()) {
    state = WalletExpenseState(
      isLoading: false,
      isMutating: false,
      items: items,
      summary: WalletExpenseSummary(
        totalAmount: items.fold(0, (sum, item) => sum + item.amount),
        count: items.length,
        currency: 'KRW',
        categories: const [],
      ),
      hasMore: false,
    );
  }

  @override
  Future<void> loadFirstPage(String petId) async {}

  @override
  Future<WalletExpense> createExpense(
    String petId,
    Map<String, dynamic> body,
  ) async {
    createdPetId = petId;
    createdBody = body;
    return _expense(id: 'created');
  }

  @override
  Future<WalletExpense> updateExpense(
    String petId,
    String expenseId,
    Map<String, dynamic> body,
  ) async {
    updatedExpenseId = expenseId;
    updatedBody = body;
    return _expense(id: expenseId);
  }

  @override
  Future<void> deleteExpense(String petId, String expenseId) async {
    deletedExpenseId = expenseId;
  }
}

class _NoopWalletExpenseService extends WalletExpenseService {}
