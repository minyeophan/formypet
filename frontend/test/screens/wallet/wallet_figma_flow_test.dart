import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/screens/wallet/expense_wallet_screen.dart';
import 'package:frontend/screens/wallet/expense_report_screen.dart';
import 'package:frontend/screens/wallet/expense_calendar_screen.dart';
import 'package:frontend/screens/wallet/wallet_expense_utils.dart';
import 'wallet_audit_screen_test.dart' show pumpWallet;
import 'wallet_test_api.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final date in [
    DateTime(DateTime.now().year + 1, 2, 15),
    DateTime(2201, 3, 4),
    DateTime(1949, 12, 31),
  ]) {
    testWidgets('calendar picker preserves the browsed date $date', (
      tester,
    ) async {
      WalletTestApi([]);
      final container = await pumpWallet(tester, const ExpenseCalendarScreen());
      container.read(walletQueryProvider.notifier).selectDate(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('${date.year}년 ${date.month}월'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-picker-done')));
      await tester.pumpAndSettle();
      expect(container.read(walletQueryProvider).selectedDate, date);
      expect(
        container.read(walletQueryProvider).calendarMonth,
        DateTime(date.year, date.month),
      );
    });
  }

  testWidgets('calendar fixed add action preserves the selected pet', (
    tester,
  ) async {
    WalletTestApi([]);
    final router = GoRouter(
      initialLocation: '/wallet/calendar',
      routes: [
        GoRoute(
          path: '/wallet/calendar',
          builder: (_, _) => const ExpenseCalendarScreen(),
        ),
        GoRoute(
          path: '/wallet/expenses/new',
          builder: (_, _) => const Scaffold(body: Text('추가 화면')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final c = await pumpWallet(tester, null, router: router);
    c.read(walletQueryProvider.notifier).setPet('p2');
    await tester.pumpAndSettle();
    final add = find.byKey(const Key('wallet-calendar-add-button'));
    expect(add.hitTestable(), findsOneWidget);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('추가 화면'), findsOneWidget);
    expect(c.read(walletQueryProvider).petId, 'p2');
  });
  testWidgets('recent all entry opens complete list with unchanged filters', (
    tester,
  ) async {
    WalletTestApi([
      expenseJson('food-entry', 'p1', amount: 7000),
      {...expenseJson('vet-entry', 'p1', amount: 9000), 'category': 'hospital'},
    ]);
    final router = GoRouter(
      initialLocation: '/wallet',
      routes: [
        GoRoute(
          path: '/wallet',
          builder: (_, _) => const ExpenseWalletScreen(),
        ),
        GoRoute(
          path: '/wallet/report',
          builder: (_, _) => const ExpenseReportScreen(),
        ),
        GoRoute(
          path: '/wallet/calendar',
          builder: (_, _) => const ExpenseCalendarScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    final c = await pumpWallet(tester, null, router: router);
    c.read(walletQueryProvider.notifier).setPet('p1');
    c.read(walletQueryProvider.notifier).setCategory('food');
    c.read(walletQueryProvider.notifier).setPeriod(WalletPeriod.all);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '새로고침'), findsNothing);
    expect(find.byTooltip('캘린더'), findsOneWidget);
    await tester.ensureVisible(find.text('전체보기'));
    await tester.tap(find.text('전체보기'));
    await tester.pumpAndSettle();
    expect(find.text('지출 리포트'), findsOneWidget);
    expect(find.text('16,000원'), findsOneWidget);
    expect(find.text('food-entry'), findsOneWidget);
    expect(find.text('vet-entry'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(c.read(walletQueryProvider).petId, 'p1');
    expect(c.read(walletQueryProvider).category, 'food');
    expect(c.read(walletQueryProvider).period, WalletPeriod.all);
  });

  testWidgets(
    'wallet filters use compact controls and calendar has no today action',
    (tester) async {
      WalletTestApi([]);
      final router = GoRouter(
        initialLocation: '/wallet',
        routes: [
          GoRoute(
            path: '/wallet',
            builder: (_, _) => const ExpenseWalletScreen(),
          ),
          GoRoute(
            path: '/wallet/calendar',
            builder: (_, _) => const ExpenseCalendarScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpWallet(tester, null, router: router);
      expect(find.byKey(const Key('wallet-period-button')), findsOneWidget);
      await tester.tap(find.byTooltip('캘린더'));
      await tester.pumpAndSettle();
      expect(find.text('오늘'), findsNothing);
    },
  );
}
