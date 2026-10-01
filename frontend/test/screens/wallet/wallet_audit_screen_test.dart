import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/screens/wallet/wallet_expense_utils.dart';
import 'package:frontend/screens/wallet/expense_calendar_screen.dart';
import 'package:frontend/screens/wallet/expense_wallet_screen.dart';
import 'package:frontend/screens/wallet/expense_detail_screen.dart';
import 'package:frontend/screens/wallet/expense_edit_screen.dart';
import 'package:frontend/screens/wallet/expense_add_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet_test_api.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final screen in [
    const ExpenseWalletScreen(),
    const ExpenseCalendarScreen(),
  ]) {
    testWidgets(
      '${screen.runtimeType} does not total a first page after later page failure',
      (tester) async {
        final api = WalletTestApi(
          List.generate(21, (i) => expenseJson('row-$i', 'p1')),
        )..failingListOffset = 20;
        final container = await pumpWallet(
          tester,
          screen,
          beforePump: (container) async {
            await container
                .read(walletExpenseProvider.notifier)
                .loadFirstPage('p1');
          },
        );
        expect(container.read(walletExpenseProvider).items, hasLength(20));
        expect(container.read(walletExpenseProvider).hasMore, isTrue);
        expect(find.textContaining('새로고침'), findsWidgets);
        expect(find.text('20,000원'), findsNothing);
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();
        expect(find.text('20,000원'), findsNothing);

        api.failingListOffset = null;
        await tester.tap(find.widgetWithText(TextButton, '새로고침'));
        await tester.pumpAndSettle();
        expect(find.text('21,000원'), findsWidgets);
      },
    );

    testWidgets(
      '${screen.runtimeType} requires coverage for every selected pet',
      (tester) async {
        final api = WalletTestApi([
          expenseJson('a', 'p1'),
          expenseJson('b', 'p2', amount: 7000),
        ]);
        await pumpWallet(
          tester,
          screen,
          beforePump: (container) async {
            await container.read(walletExpenseProvider.notifier).loadAllPets([
              'p1',
            ]);
            api.listFails = true;
          },
        );
        expect(find.textContaining('새로고침'), findsWidgets);
        if (screen is ExpenseWalletScreen) {
          expect(find.byKey(const Key('wallet-period-total')), findsNothing);
        } else {
          expect(find.text('—'), findsOneWidget);
        }
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();
        if (screen is ExpenseWalletScreen) {
          expect(find.byKey(const Key('wallet-period-total')), findsOneWidget);
        } else {
          expect(find.text('—'), findsNothing);
        }
        expect(find.text('1,000원'), findsWidgets);
      },
    );
  }

  for (final screen in [
    const ExpenseWalletScreen(),
    const ExpenseCalendarScreen(),
  ]) {
    testWidgets(
      '${screen.runtimeType} failed initial load is not a complete zero total',
      (tester) async {
        WalletTestApi([]).listFails = true;
        await pumpWallet(tester, screen);
        expect(find.textContaining('새로고침'), findsWidgets);
        expect(find.text('0원'), findsNothing);
      },
    );
  }

  testWidgets(
    'detail and delete use selected expense owner even with another active pet',
    (tester) async {
      final api = WalletTestApi([expenseJson('b-expense', 'p2')]);
      final router = ownerRouter('/wallet/expenses/b-expense?petId=p2');
      addTearDown(router.dispose);
      await pumpWallet(tester, null, router: router);
      expect(find.text('b-expense'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      api.summaryFails = true;
      await tester.tap(find.byKey(const Key('expense-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense-delete-confirm-button')));
      await tester.pumpAndSettle();
      expect(find.text('wallet-home'), findsOneWidget);
      expect(find.textContaining('새로고침'), findsOneWidget);
      expect(
        api.requests.where((r) => r.method == 'DELETE').single.path,
        '/api/v1/pets/p2/wallet/expenses/b-expense',
      );
    },
  );

  testWidgets(
    'edit saves to selected owner and keeps ownership in return route',
    (tester) async {
      final api = WalletTestApi([expenseJson('b-expense', 'p2')]);
      final router = ownerRouter('/wallet/expenses/b-expense/edit?petId=p2');
      addTearDown(router.dispose);
      await pumpWallet(tester, null, router: router);
      expect(find.text('B'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('expense-memo-field')),
        'updated',
      );
      api.summaryFails = true;
      await tester.tap(find.byKey(const Key('expense-save-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-delete-button')), findsOneWidget);
      expect(find.text('updated'), findsOneWidget);
      expect(find.textContaining('새로고침'), findsWidgets);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['petId'],
        'p2',
      );
      expect(
        api.requests.where((r) => r.method == 'PUT').single.path,
        '/api/v1/pets/p2/wallet/expenses/b-expense',
      );
    },
  );

  testWidgets(
    'successful add navigates home and shows summary refresh warning',
    (tester) async {
      final api = WalletTestApi([])..summaryFails = true;
      final router = ownerRouter('/wallet/expenses/new');
      addTearDown(router.dispose);
      await pumpWallet(tester, null, router: router);
      await tester.tap(find.byKey(const Key('expense-pet-p1')));
      await tester.tap(find.byKey(const Key('expense-amount-input')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-number-key-5')));
      await tester.tap(find.byKey(const Key('record-picker-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense-category-food')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('wallet-home'), findsOneWidget);
      expect(find.textContaining('새로고침'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  testWidgets('wallet includes all 21 expenses in total and count', (
    tester,
  ) async {
    WalletTestApi(List.generate(21, (i) => expenseJson('row-$i', 'p1')));
    await pumpWallet(tester, const ExpenseWalletScreen());
    expect(find.text('21,000원'), findsWidgets);
    expect(find.textContaining('21건'), findsOneWidget);
  });

  testWidgets('calendar includes a date found only on the second page', (
    tester,
  ) async {
    WalletTestApi([
      ...List.generate(
        20,
        (i) => expenseJson('old-$i', 'p1', date: '2020-01-01'),
      ),
      expenseJson('second-page', 'p1', amount: 7300),
    ]);
    await pumpWallet(tester, const ExpenseCalendarScreen());
    expect(find.text('second-page'), findsOneWidget);
    expect(find.text('7,300원'), findsWidgets);
  });

  for (final screen in [
    const ExpenseWalletScreen(),
    const ExpenseCalendarScreen(),
  ]) {
    testWidgets('${screen.runtimeType} reacts to CRUD with summary failure', (
      tester,
    ) async {
      final api = WalletTestApi([expenseJson('old', 'p1')]);
      final container = await pumpWallet(tester, screen);
      final wallet = container.read(walletExpenseProvider.notifier);
      api.summaryFails = true;
      await tester.runAsync(() async {
        try {
          await wallet.updateExpense('p1', 'old', {'amount': 7300});
        } catch (_) {}
      });
      await tester.pumpAndSettle();
      expect(find.text('7,300원'), findsWidgets);
      expect(find.textContaining('새로고침'), findsWidgets);
      await tester.runAsync(() async {
        try {
          await wallet.createExpense('p1', {'amount': 500});
        } catch (_) {}
      });
      await tester.pumpAndSettle();
      expect(find.text('7,800원'), findsWidgets);
      await tester.runAsync(() async {
        try {
          await wallet.deleteExpense('p1', 'old');
        } catch (_) {}
      });
      await tester.pumpAndSettle();
      expect(find.text('7,300원'), findsNothing);
      expect(find.text('500원'), findsWidgets);
    });
  }

  testWidgets('monthly budget ignores historical expense in all period total', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'wallet_monthly_budget': 5000});
    WalletTestApi([
      expenseJson('historical', 'p1', date: '2020-01-01', amount: 9000),
    ]);
    final container = await pumpWallet(tester, const ExpenseWalletScreen());
    container.read(walletQueryProvider.notifier).setPeriod(WalletPeriod.all);
    await tester.pumpAndSettle();
    expect(find.text('9,000원'), findsWidgets);
    expect(find.textContaining('초과'), findsNothing);
  });

  testWidgets('selected pet expense route carries its owner', (tester) async {
    WalletTestApi([expenseJson('b-expense', 'p2')]);
    final router = GoRouter(
      initialLocation: '/wallet',
      routes: [
        GoRoute(
          path: '/wallet',
          builder: (_, _) => const ExpenseWalletScreen(),
        ),
        GoRoute(
          path: '/wallet/expenses/:expenseId',
          builder: (_, state) =>
              Text('owner=${state.uri.queryParameters['petId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpWallet(tester, null, router: router);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet-expense-row-b-expense')));
    await tester.pumpAndSettle();
    expect(find.text('owner=p2'), findsOneWidget);
  });
}

Future<ProviderContainer> pumpWallet(
  WidgetTester tester,
  Widget? screen, {
  GoRouter? router,
  Future<void> Function(ProviderContainer)? beforePump,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(
        (ref) => AuthNotifier.test(
          const AuthState(
            isLoading: false,
            isAuthenticated: true,
            profile: UserProfile(
              id: 'wallet-test-user',
              email: 'wallet@test.local',
              nickname: '집사',
            ),
          ),
        ),
      ),
      petProvider.overrideWith((ref) => PetNotifier.test(walletPets())),
    ],
  );
  addTearDown(container.dispose);
  if (beforePump != null) await tester.runAsync(() => beforePump(container));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: router == null
          ? MaterialApp(home: screen)
          : MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

PetState walletPets() => const PetState(
  isLoading: false,
  hasOnboarded: true,
  activePetId: 'p1',
  pets: [
    Pet(
      id: 'p1',
      name: 'A',
      species: 'dog',
      birthDate: '2022-01-01',
      accentColor: '#F4A460',
      bgLight: '#FFF8F0',
    ),
    Pet(
      id: 'p2',
      name: 'B',
      species: 'cat',
      birthDate: '2022-01-01',
      accentColor: '#F4A460',
      bgLight: '#FFF8F0',
    ),
  ],
  records: [],
  routines: [],
  todayRoutineItems: [],
  routineCompletions: {},
  quickTypeIds: [],
);

GoRouter ownerRouter(String location) => GoRouter(
  initialLocation: location,
  routes: [
    GoRoute(
      path: '/wallet',
      builder: (_, _) => const Scaffold(body: Text('wallet-home')),
    ),
    GoRoute(
      path: '/wallet/expenses/new',
      builder: (_, _) => const ExpenseAddScreen(),
    ),
    GoRoute(
      path: '/wallet/expenses/:expenseId',
      builder: (_, state) => ExpenseDetailScreen(
        expenseId: state.pathParameters['expenseId']!,
        petId: state.uri.queryParameters['petId'],
      ),
    ),
    GoRoute(
      path: '/wallet/expenses/:expenseId/edit',
      builder: (_, state) => ExpenseEditScreen(
        expenseId: state.pathParameters['expenseId']!,
        petId: state.uri.queryParameters['petId'],
      ),
    ),
  ],
);
