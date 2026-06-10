import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/wallet/expense_report_screen.dart';
import 'package:frontend/screens/wallet/expense_wallet_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('wallet screen shows totals and recent expenses', (tester) async {
    await _pumpScreen(tester, const ExpenseWalletScreen());

    expect(find.text('집사의 지갑'), findsOneWidget);
    expect(find.text('비용 추가'), findsOneWidget);
    expect(find.text('내역 보기'), findsOneWidget);
    expect(find.text('35,000원'), findsOneWidget);
    expect(find.text('간식'), findsOneWidget);
    expect(find.text('병원 메모'), findsOneWidget);
    expect(find.textContaining('기타'), findsOneWidget);
    expect(
      find.byKey(const Key('wallet-expense-row-expense-food')),
      findsOneWidget,
    );
    expect(find.text('준비중'), findsNothing);
    expect(find.text('빠른 지출'), findsNothing);
  });

  testWidgets('wallet recent expense row opens wallet expense detail route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/wallet',
      routes: [
        GoRoute(
          path: '/wallet',
          builder: (_, _) => const ExpenseWalletScreen(),
        ),
        GoRoute(
          path: '/wallet/expenses/:recordId',
          builder: (_, state) => Text(state.pathParameters['recordId']!),
        ),
      ],
    );
    await _pumpRouter(tester, router);

    await tester.tap(find.byKey(const Key('wallet-expense-row-expense-food')));
    await tester.pumpAndSettle();

    expect(find.text('expense-food'), findsOneWidget);
  });

  testWidgets('report screen shows category summary and opens detail route', (
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
          path: '/wallet/expenses/:recordId',
          builder: (_, state) => Text(state.pathParameters['recordId']!),
        ),
      ],
    );
    await _pumpRouter(tester, router);

    expect(find.text('지출 리포트'), findsOneWidget);
    expect(find.text('2026-05-20 - 2026-05-21'), findsOneWidget);
    expect(find.text('35,000원'), findsWidgets);
    expect(find.text('식비'), findsOneWidget);
    expect(find.text('15,000원'), findsWidgets);
    expect(find.text('기타'), findsWidgets);
    expect(find.text('20,000원'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('wallet-report-expense-row-expense-food')),
    );
    await tester.pumpAndSettle();

    expect(find.text('expense-food'), findsOneWidget);
  });
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => PetNotifier.test(_state())),
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
        petProvider.overrideWith((ref) => PetNotifier.test(_state())),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

PetState _state() => PetState(
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
      id: 'expense-food',
      petId: 'pet-1',
      typeId: 'expense',
      date: '2026-05-21',
      time: '09:00',
      detail: {'itemName': '간식', 'amount': 15000, 'category': '식비'},
    ),
    ActivityRecord(
      id: 'expense-note',
      petId: 'pet-1',
      typeId: 'expense',
      date: '2026-05-20',
      time: '18:00',
      note: '병원 메모',
      detail: {'amount': 20000},
    ),
    ActivityRecord(
      id: 'meal',
      petId: 'pet-1',
      typeId: 'meal',
      date: '2026-05-21',
    ),
  ],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);
