import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/screens/wallet/wallet_expense_utils.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/screens/wallet/expense_wallet_screen.dart';
import 'package:frontend/screens/wallet/expense_report_screen.dart';
import 'package:frontend/screens/wallet/expense_calendar_screen.dart';
import 'package:frontend/screens/wallet/expense_form.dart';
import 'package:frontend/screens/wallet/expense_detail_screen.dart';
import 'wallet_audit_screen_test.dart' show pumpWallet;
import 'wallet_test_api.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'wallet_monthly_budget': 50000,
    }),
  );
  testWidgets(
    'query survives report calendar and back without broad period changes',
    (tester) async {
      WalletTestApi([expenseJson('b', 'p2', amount: 3000)]);
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
      final container = await pumpWallet(tester, null, router: router);
      final query = container.read(walletQueryProvider.notifier);
      query.setPet('p2');
      query.setPeriod(WalletPeriod.year);
      query.setCategory('food');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('전체보기'));
      await tester.tap(find.text('전체보기'));
      await tester.pumpAndSettle();
      expect(find.text('3,000원'), findsWidgets);
      await tester.tap(find.byTooltip('캘린더'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
      expect(container.read(walletQueryProvider).period, WalletPeriod.year);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(container.read(walletQueryProvider).petId, 'p2');
      expect(container.read(walletQueryProvider).category, 'food');
      expect(container.read(walletQueryProvider).period, WalletPeriod.year);
    },
  );
  testWidgets('budget rejects negative input and persists valid amount', (
    tester,
  ) async {
    WalletTestApi([]);
    await pumpWallet(tester, const ExpenseWalletScreen());
    await tester.tap(find.text('예산 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('wallet-budget-input')),
      '-100',
    );
    await tester.ensureVisible(find.byKey(const Key('wallet-budget-save')));
    await tester.tap(find.byKey(const Key('wallet-budget-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-budget-input')), findsOneWidget);
    expect(find.text('예산은 0원보다 크게 입력해 주세요.'), findsOneWidget);
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    expect(
      (await SharedPreferences.getInstance()).getInt(
        'wallet_monthly_budget_v2:wallet-test-user:$month',
      ),
      50000,
    );
    await tester.enterText(
      find.byKey(const Key('wallet-budget-input')),
      '25000',
    );
    await tester.ensureVisible(find.byKey(const Key('wallet-budget-save')));
    await tester.tap(find.byKey(const Key('wallet-budget-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-budget-input')), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getInt(
        'wallet_monthly_budget_v2:wallet-test-user:$month',
      ),
      25000,
    );
    expect(find.text('월 예산 25,000원'), findsOneWidget);
  });
  testWidgets(
    'selected pet and category do not narrow budget or period total',
    (tester) async {
      WalletTestApi([
        expenseJson('food', 'p1', amount: 10000),
        {...expenseJson('vet', 'p1', amount: 5000), 'category': 'hospital'},
        expenseJson('other', 'p2', amount: 20000),
      ]);
      final container = await pumpWallet(tester, const ExpenseWalletScreen());
      container.read(walletQueryProvider.notifier).setPet('p1');
      container.read(walletQueryProvider.notifier).setCategory('food');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('wallet-period-total')),
          matching: find.text('15,000원'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('사용 35,000원'), findsOneWidget);
      expect(find.text('월 예산 50,000원'), findsOneWidget);
      expect(find.text('잔액 15,000원'), findsOneWidget);
      expect(find.text('vet'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('report failure does not present zero as completed result', (
    tester,
  ) async {
    WalletTestApi([]).listFails = true;
    await pumpWallet(tester, const ExpenseReportScreen());
    expect(find.text('0원'), findsNothing);
    expect(find.textContaining('새로고침'), findsWidgets);
  });
  testWidgets('report shows more locally without extra page request', (
    tester,
  ) async {
    final api = WalletTestApi(
      List.generate(25, (i) => expenseJson('row-$i', 'p1')),
    );
    await pumpWallet(tester, const ExpenseReportScreen());
    final count = api.requests.length;
    expect(find.text('25,000원'), findsWidgets);
    final more = find.byKey(const Key('wallet-load-more-button'));
    await tester.scrollUntilVisible(
      more,
      500,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(api.requests.length, count);
    expect(more, findsNothing);
  });
  for (final width in [360.0, 390.0, 1000.0]) {
    testWidgets('expense form fits $width with large text and long owner', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: ExpenseFormBody(
                mode: ExpenseFormMode.edit,
                initialData: ExpenseFormData(
                  date: DateTime(2026, 9, 8),
                  time: const TimeOfDay(hour: 9, minute: 0),
                  amount: 999999999,
                  category: 'food',
                  itemName: '긴 지출 항목 이름입니다',
                  note: '메모',
                ),
                petName: '아주 긴 이름을 가진 소중한 반려동물입니다',
                submitting: false,
                errorText: null,
                onSubmit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('expense-save-button')),
        400,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('expense detail fits $width with large text and amount', (
      tester,
    ) async {
      WalletTestApi([
        {
          ...expenseJson('detail', 'p1', amount: 999999999),
          'itemName': '아주 긴 지출 항목 이름과 설명입니다',
          'note': '상세한 지출 메모를 확인합니다.',
        },
      ]);
      await pumpWallet(
        tester,
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: ExpenseDetailScreen(expenseId: 'detail', petId: 'p1'),
        ),
      );
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    for (final screen in [
      const ExpenseWalletScreen(),
      const ExpenseReportScreen(),
      const ExpenseCalendarScreen(),
    ]) {
      testWidgets('${screen.runtimeType} fits $width with large text', (
        tester,
      ) async {
        WalletTestApi([
          expenseJson(
            'long-title-long-title-long-title',
            'p1',
            amount: 999999999,
          ),
        ]);
        await pumpWallet(
          tester,
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: screen,
          ),
        );
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
