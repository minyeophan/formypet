// Run only in the separate MuMu QA package against the disposable JPA DB.
// Use --no-uninstall on both runs. Repeat with VERIFY_EXISTING_WALLET=true
// to verify a new app process reads
// the same persisted credentials, pet and expenses without creating fixtures.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_view_provider.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/wallet/wallet_widgets.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:frontend/widgets/app_text.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('JPA wallet UI filters, report and restart persistence', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    expect(
      (await getExternalStorageDirectory())!.path,
      contains('com.formypet.frontend.mediatest/'),
    );
    initApiClient('http://127.0.0.1:18083');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_WALLET');
    if (!existing) {
      final random = Random.secure();
      await AuthService().register(
        email:
            'wallet-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
        password: List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join(),
        nickname: 'JPA 검증',
      );
      final pet = await PetService().createPet({
        'name': 'JPA 검증 펫',
        'species': 'dog',
        'birthDate': '2022-03-15',
      });
      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-15';
      for (final entry in [
        ('food', 12000, 'JPA 사료'),
        ('hospital', 8000, 'JPA 진료'),
      ]) {
        await WalletExpenseService().createExpense(pet.id, {
          'expenseDate': date,
          'expenseTime': '09:10:11',
          'amount': entry.$2,
          'currency': 'KRW',
          'category': entry.$1,
          'itemName': entry.$3,
        });
      }
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FormypetApp(),
      ),
    );
    await _until(
      tester,
      () =>
          !container.read(authProvider).isLoading &&
          !container.read(petProvider).isLoading,
    );
    expect(container.read(authProvider).isAuthenticated, isTrue);
    final pets = await PetService().getPets();
    final pet = pets.singleWhere((p) => p.name == 'JPA 검증 펫');
    final expenses = await WalletExpenseService().listAllExpenses(pet.id);
    expect(expenses, hasLength(2));
    expect(expenses.map((e) => e.amount).reduce((a, b) => a + b), 20000);
    final router = container.read(routerProvider);
    router.go('/wallet/report');
    container
        .read(walletQueryProvider.notifier)
        .setMonth(DateTime.parse(expenses.first.expenseDate));
    await _until(
      tester,
      () =>
          container.read(walletViewProvider).available &&
          !container.read(walletViewProvider).loading,
    );
    final total = find.byKey(const Key('wallet-period-total'));
    await tester.ensureVisible(total);
    expect(tester.widget<AppText>(total).text, '20,000원');
    final categories = find.byType(WalletCategorySelector);
    final food = find.descendant(of: categories, matching: find.text('사료'));
    await _tap(tester, food);
    expect(find.text('JPA 사료'), findsOneWidget);
    expect(find.text('JPA 진료'), findsNothing);
    final hospital = find.descendant(of: categories, matching: find.text('병원'));
    await _tap(tester, hospital);
    expect(find.text('JPA 사료'), findsNothing);
    expect(find.text('JPA 진료'), findsOneWidget);
    await _tap(
      tester,
      find.descendant(of: categories, matching: find.text('전체')),
    );
    expect(find.text('JPA 사료'), findsOneWidget);
    expect(find.text('JPA 진료'), findsOneWidget);
    await _tap(tester, find.byTooltip('이전 달'));
    expect(tester.widget<AppText>(total).text, '0원');
    expect(find.text('JPA 사료'), findsNothing);
    await _tap(tester, find.byTooltip('다음 달'));
    expect(tester.widget<AppText>(total).text, '20,000원');
    expect(find.text('JPA 사료'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'WALLET_RESTART_VERIFIED' : 'WALLET_UI_VERIFIED');
  });
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Wallet UI did not become ready');
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
