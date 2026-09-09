import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/screens/wallet/wallet_expense_utils.dart';
import 'package:frontend/screens/wallet/wallet_widgets.dart';
import 'wallet_audit_screen_test.dart' show pumpWallet;
import 'wallet_test_api.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('period sheet stages changes and back discards them', (
    tester,
  ) async {
    WalletTestApi([]);
    final container = await pumpWallet(
      tester,
      const WalletPage(title: '필터', children: [WalletFilters()]),
    );
    final notifier = container.read(walletQueryProvider.notifier);
    notifier.setPet('p2');
    notifier.setCategory('food');
    notifier.setMonth(DateTime(2025, 2));
    await tester.pumpAndSettle();
    expect(find.text('올해'), findsNothing);
    await tester.tap(find.byTooltip('기간 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 기간'));
    await tester.pumpAndSettle();
    expect(container.read(walletQueryProvider).period, WalletPeriod.month);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(walletQueryProvider).baseMonth, DateTime(2025, 2));
    expect(container.read(walletQueryProvider).petId, 'p2');
    expect(container.read(walletQueryProvider).category, 'food');
  });

  testWidgets('apply picks historical month preserving pet and category', (
    tester,
  ) async {
    WalletTestApi([]);
    final container = await pumpWallet(
      tester,
      const WalletPage(title: '필터', children: [WalletFilters()]),
    );
    final notifier = container.read(walletQueryProvider.notifier);
    notifier.setPet('p2');
    notifier.setCategory('food');
    notifier.setMonth(DateTime(2026, 9));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('기간 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이전 연도'));
    await tester.tap(find.text('2월'));
    await tester.pumpAndSettle();
    expect(find.text('2025.02.01 – 2025.02.28'), findsOneWidget);
    expect(container.read(walletQueryProvider).baseMonth, DateTime(2026, 9));
    await tester.tap(find.text('적용하기'));
    await tester.pumpAndSettle();
    final query = container.read(walletQueryProvider);
    expect(query.baseMonth, DateTime(2025, 2));
    expect(query.petId, 'p2');
    expect(query.category, 'food');
    expect(find.byTooltip('이전 달'), findsOneWidget);
    expect(find.text('2025년 2월'), findsOneWidget);
  });

  for (final label in ['올해', '전체 기간']) {
    testWidgets('$label apply hides month arrows and survives reopen', (
      tester,
    ) async {
      WalletTestApi([]);
      final container = await pumpWallet(
        tester,
        const WalletPage(title: '필터', children: [WalletFilters()]),
      );
      await tester.tap(find.byTooltip('기간 설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.tap(find.text('적용하기'));
      await tester.pumpAndSettle();
      expect(
        container.read(walletQueryProvider).period,
        label == '올해' ? WalletPeriod.year : WalletPeriod.all,
      );
      expect(find.byTooltip('이전 달'), findsNothing);
      expect(find.byTooltip('다음 달'), findsNothing);
      expect(
        find.text(label == '올해' ? '${DateTime.now().year}년' : '전체 기간'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('기간 설정'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          label == '올해' ? '${DateTime.now().year}년 전체 지출' : '등록된 모든 지출',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('an open period draft cannot modify a replacement session', (
    tester,
  ) async {
    WalletTestApi([]);
    final container = await pumpWallet(
      tester,
      const WalletPage(title: '필터', children: [WalletFilters()]),
    );
    await tester.tap(find.byTooltip('기간 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 기간'));
    container
        .read(walletExpenseProvider.notifier)
        .resetSession(authenticated: true);
    await tester.tap(find.text('적용하기'));
    await tester.pumpAndSettle();
    expect(container.read(walletQueryProvider).period, WalletPeriod.month);
  });

  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(760, 390),
  ]) {
    testWidgets('period apply stays reachable at $size and large text', (
      tester,
    ) async {
      WalletTestApi([]);
      final container = await pumpWallet(
        tester,
        const WalletPage(title: '필터', children: [WalletFilters()]),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const WalletPage(title: '필터', children: [WalletFilters()]),
          ),
        ),
      );
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('기간 설정'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('적용하기').hitTestable(), findsOneWidget);
      await tester.tap(find.text('적용하기'));
      await tester.pumpAndSettle();
      expect(find.text('적용하기'), findsNothing);
    });
  }
}
