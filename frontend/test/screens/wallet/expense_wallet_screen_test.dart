import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/wallet_expense.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/screens/wallet/expense_report_screen.dart';
import 'package:frontend/screens/wallet/expense_wallet_screen.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('wallet screen shows summary and recent wallet expenses', (
    tester,
  ) async {
    await _pumpScreen(tester, const ExpenseWalletScreen());

    expect(find.text('\uC9D1\uC0AC\uC758 \uC9C0\uAC11'), findsOneWidget);
    expect(find.text('35,000\uC6D0'), findsOneWidget);
    expect(find.text('\uAC04\uC2DD'), findsOneWidget);
    expect(
      find.byKey(const Key('wallet-expense-row-expense-food')),
      findsOneWidget,
    );
  });

  testWidgets('wallet recent row opens expense detail route', (tester) async {
    final router = GoRouter(
      initialLocation: '/wallet',
      routes: [
        GoRoute(
          path: '/wallet',
          builder: (_, _) => const ExpenseWalletScreen(),
        ),
        GoRoute(
          path: '/wallet/expenses/:expenseId',
          builder: (_, state) => Text(state.pathParameters['expenseId']!),
        ),
      ],
    );
    await _pumpRouter(tester, router);

    await tester.tap(find.byKey(const Key('wallet-expense-row-expense-food')));
    await tester.pumpAndSettle();

    expect(find.text('expense-food'), findsOneWidget);
  });

  testWidgets('wallet recent row keeps its surface and shows focus border', (
    tester,
  ) async {
    await _pumpScreen(tester, const ExpenseWalletScreen());

    await _expectRowInteraction(
      tester,
      const Key('wallet-expense-row-expense-food'),
    );
  });

  testWidgets('report screen shows summary and opens detail route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/wallet/report',
      routes: [
        GoRoute(
          path: '/wallet/report',
          builder: (_, _) => const ExpenseReportScreen(),
        ),
        GoRoute(
          path: '/wallet/expenses/:expenseId',
          builder: (_, state) => Text(state.pathParameters['expenseId']!),
        ),
      ],
    );
    await _pumpRouter(tester, router);

    expect(find.text('\uC9C0\uCD9C \uB9AC\uD3EC\uD2B8'), findsOneWidget);
    expect(find.text('35,000\uC6D0'), findsWidgets);
    await tester.tap(
      find.byKey(const Key('wallet-report-expense-row-expense-food')),
    );
    await tester.pumpAndSettle();

    expect(find.text('expense-food'), findsOneWidget);
  });

  testWidgets('report row keeps its surface and shows focus border', (
    tester,
  ) async {
    await _pumpScreen(tester, const ExpenseReportScreen());

    await _expectRowInteraction(
      tester,
      const Key('wallet-report-expense-row-expense-food'),
    );
  });
}

Future<void> _expectRowInteraction(WidgetTester tester, Key materialKey) async {
  final materialFinder = find.byKey(materialKey);
  var material = tester.widget<Material>(materialFinder);
  var inkWell = material.child! as InkWell;

  expect(inkWell.hoverColor, Colors.transparent);
  expect(inkWell.focusColor, Colors.transparent);
  expect(inkWell.highlightColor, Colors.transparent);
  expect(inkWell.splashColor, AppColors.text.withValues(alpha: 0.06));
  expect(inkWell.onFocusChange, isNotNull);

  inkWell.onFocusChange!(true);
  await tester.pump();

  material = tester.widget<Material>(materialFinder);
  inkWell = material.child! as InkWell;
  var decoration = (inkWell.child! as Container).decoration! as BoxDecoration;
  var border = decoration.border! as Border;
  expect(border.top.color, AppColors.textSecondary);
  expect(border.top.width, 2);

  inkWell.onFocusChange!(false);
  await tester.pump();

  material = tester.widget<Material>(materialFinder);
  inkWell = material.child! as InkWell;
  decoration = (inkWell.child! as Container).decoration! as BoxDecoration;
  border = decoration.border! as Border;
  expect(border.top.color, AppColors.border);
  expect(border.top.width, 1);
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => PetNotifier.test(_petState())),
        walletExpenseProvider.overrideWith(
          (ref) => _WalletNotifier(_walletState()),
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => PetNotifier.test(_petState())),
        walletExpenseProvider.overrideWith(
          (ref) => _WalletNotifier(_walletState()),
        ),
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

WalletExpenseState _walletState() {
  final items = [
    _expense(
      id: 'expense-food',
      amount: 15000,
      category: 'snack',
      categoryLabel: '\uAC04\uC2DD',
      itemName: '\uAC04\uC2DD',
      date: '2026-05-21',
    ),
    _expense(
      id: 'expense-note',
      amount: 20000,
      category: 'etc',
      categoryLabel: '\uAE30\uD0C0',
      note: '\uBCD1\uC6D0 \uBA54\uBAA8',
      date: '2026-05-20',
    ),
  ];
  return WalletExpenseState(
    isLoading: false,
    isMutating: false,
    items: items,
    summary: const WalletExpenseSummary(
      totalAmount: 35000,
      count: 2,
      currency: 'KRW',
      categories: [
        WalletExpenseCategorySummary(
          category: 'snack',
          categoryLabel: '\uAC04\uC2DD',
          amount: 15000,
          count: 1,
        ),
        WalletExpenseCategorySummary(
          category: 'etc',
          categoryLabel: '\uAE30\uD0C0',
          amount: 20000,
          count: 1,
        ),
      ],
    ),
    hasMore: false,
  );
}

WalletExpense _expense({
  required String id,
  required int amount,
  required String category,
  required String categoryLabel,
  required String date,
  String? itemName,
  String? note,
}) => WalletExpense(
  id: id,
  petId: 'pet-1',
  expenseDate: date,
  expenseTime: '09:00',
  amount: amount,
  currency: 'KRW',
  category: category,
  categoryLabel: categoryLabel,
  itemName: itemName,
  note: note,
);

class _WalletNotifier extends WalletExpenseNotifier {
  _WalletNotifier(WalletExpenseState initial) : super(_NoopService()) {
    state = initial;
  }

  @override
  Future<void> loadFirstPage(String petId) async {}
}

class _NoopService extends WalletExpenseService {}
