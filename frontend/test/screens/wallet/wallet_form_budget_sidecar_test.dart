import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/screens/wallet/expense_form.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/models/wallet_expense.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/providers/wallet_view_provider.dart';
import 'package:frontend/services/wallet_budget_service.dart';
import 'package:frontend/screens/wallet/wallet_budget_card.dart';
import 'package:frontend/screens/wallet/wallet_expense_utils.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The platform store is the persistence boundary; keep the real service/UI.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'wallet_form_redesign_test.dart' as forms;
import 'wallet_review_regression_test.dart' as review;
import 'wallet_test_api.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Existing shipped font; no generated font assets or preview harness.
    await (FontLoader('WalletLayoutTest')..addFont(
          rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf'),
        ))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final alreadyOpen in [false, true]) {
    testWidgets(
      'P2 cached budget refresh failure has retry open=$alreadyOpen',
      (tester) async {
        final api = WalletTestApi([
          expenseJson('e1', 'p1', date: '2025-02-01'),
        ]);
        final wallet = WalletExpenseNotifier(WalletExpenseService());
        await tester.runAsync(() => wallet.ensureAllPets(['p1', 'p2']));
        await pumpBudget(tester, wallet: wallet);
        if (alreadyOpen) await openBudget(tester);
        api.listFails = true;
        Object? refreshFailure;
        unawaited(
          wallet.refreshWallet(['p1', 'p2']).catchError((Object error) {
            refreshFailure = error;
          }),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(refreshFailure, isNotNull);
        if (!alreadyOpen) await openBudget(tester);
        await tester.pumpAndSettle();
        expect(find.text('1,000원'), findsWidgets);
        expect(find.textContaining('최근 저장된 지출'), findsOneWidget);
        expect(find.widgetWithText(TextButton, '다시 시도'), findsOneWidget);
        api.listFails = false;
        api.rows.add(expenseJson('e2', 'p2', amount: 2000, date: '2025-02-02'));
        await tester.ensureVisible(find.text('다시 시도'));
        await tester.tap(find.text('다시 시도'));
        await tester.pumpAndSettle();
        expect(find.text('3,000원'), findsWidgets);
        expect(find.textContaining('최근 저장된 지출'), findsNothing);
        expect(find.text('다시 시도'), findsNothing);
      },
    );
  }

  testWidgets('P2 cached budget summary warning retries the summary too', (
    tester,
  ) async {
    final api = WalletTestApi([expenseJson('e1', 'p1', date: '2025-02-01')]);
    final wallet = WalletExpenseNotifier(WalletExpenseService());
    await tester.runAsync(() => wallet.ensureAllPets(['p1', 'p2']));
    api.summaryFails = true;
    await tester.runAsync(
      () => wallet.createExpense('p1', {
        'expenseDate': '2025-02-02',
        'expenseTime': '09:00',
        'amount': 2000,
        'currency': 'KRW',
        'category': 'food',
      }),
    );
    await pumpBudget(tester, wallet: wallet);
    await openBudget(tester);
    expect(find.text('3,000원'), findsWidgets);
    expect(find.textContaining('최근 저장된 지출'), findsOneWidget);
    api.summaryFails = false;
    await tester.ensureVisible(find.text('다시 시도'));
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(wallet.state.refreshWarning, isNull);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets(
    'P2 populated pet error waits for real data retry before expenses',
    (tester) async {
      final api = review.PetRecoveryApi([
        expenseJson('e1', 'p1', date: '2025-02-01'),
      ]);
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      api.recordsGate = gate.future;
      final pets = PetNotifier.test(
        review.petState(error: '반려동물 정보를 불러오지 못했어요. 다시 시도해 주세요.'),
      );
      final wallet = WalletExpenseNotifier(WalletExpenseService());
      await pumpBudget(tester, pets: pets, wallet: wallet);
      await openBudget(tester);
      await tester.ensureVisible(find.text('다시 시도'));
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(pets.state.isLoading, isTrue);
      expect(api.requests.where((r) => r.path.contains('/wallet/')), isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      expect(pets.state.dataErrorText, isNull);
      expect(find.text('1,000원'), findsWidgets);
      expect(find.text('다시 시도'), findsNothing);
    },
  );

  for (final changeAccount in [false, true]) {
    testWidgets(
      'P2 pet recovery ignores stale completion account=$changeAccount',
      (tester) async {
        final api = review.PetRecoveryApi([
          expenseJson('e1', 'p1', date: '2025-02-01'),
        ]);
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        api.recordsGate = gate.future;
        final pets = PetNotifier.test(
          review.petState(error: '반려동물 정보를 불러오지 못했어요. 다시 시도해 주세요.'),
        );
        final wallet = WalletExpenseNotifier(WalletExpenseService());
        final (_, auth) = await pumpBudget(tester, pets: pets, wallet: wallet);
        await openBudget(tester);
        await tester.ensureVisible(find.text('다시 시도'));
        await tester.tap(find.text('다시 시도'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(pets.state.isLoading, isTrue);
        if (changeAccount) {
          auth.signIn('bob');
        } else {
          wallet.resetSession(authenticated: true);
        }
        await tester.pump();
        gate.complete();
        await tester.pumpAndSettle();
        expect(api.requests.where((r) => r.path.contains('/wallet/')), isEmpty);
        expect(find.text('계정이 변경되었어요. 예산 설정을 다시 열어 주세요.'), findsOneWidget);
      },
    );
  }

  for (final width in [360.0, 390.0]) {
    for (final scale in [1.0, 1.8]) {
      for (final budget in [false, true]) {
        testWidgets(
          'P2 full amount visible width=$width scale=$scale budget=$budget',
          (tester) async {
            if (budget) {
              await pumpBudget(
                tester,
                width: width,
                scale: scale,
                layoutFont: true,
              );
              await openBudget(tester);
              await tester.enterText(
                find.byKey(const Key('wallet-budget-input')),
                '100000000',
              );
              tester.testTextInput.hide();
              FocusManager.instance.primaryFocus?.unfocus();
            } else {
              await pumpAmountForm(tester, width: width, scale: scale);
              await forms.enterAmount(tester, '100000000');
            }
            await tester.pumpAndSettle();
            final key = Key(
              budget ? 'wallet-budget-input' : 'expense-amount-input',
            );
            await tester.ensureVisible(find.byKey(key));
            await tester.pumpAndSettle();
            expectWholeAmount(tester, key, '100,000,000원');
            expect(tester.takeException(), isNull);
            if (budget) {
              // Re-enter after responsive relayout: numeric editing stays usable.
              await tester.enterText(find.byKey(key), '123456');
              tester.testTextInput.hide();
              FocusManager.instance.primaryFocus?.unfocus();
              await tester.pumpAndSettle();
              expectWholeAmount(tester, key, '123,456원');
            }
          },
        );
      }
    }
  }

  for (final budget in [false, true]) {
    testWidgets(
      'P2 normal 390 amount and puppy stay side by side budget=$budget',
      (tester) async {
        if (budget) {
          SharedPreferences.setMockInitialValues({
            'wallet_monthly_budget_v2:alice:2025-02': 150000,
          });
          await pumpBudget(tester, layoutFont: true);
          await openBudget(tester);
        } else {
          await pumpAmountForm(tester);
          await forms.enterAmount(tester, '150000');
        }
        final key = Key(
          budget ? 'wallet-budget-input' : 'expense-amount-input',
        );
        expectWholeAmount(tester, key, '150,000원');
        final field = tester.getRect(find.byKey(key));
        final puppyFinder = find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.width == (budget ? 118 : 140) &&
              w.height == 112,
        );
        final puppy = tester.getRect(puppyFinder);
        expect(field.right, lessThanOrEqualTo(puppy.left));
        expect(field.center.dy, inInclusiveRange(puppy.top, puppy.bottom));
        expect(tester.widget<SvgPicture>(puppyFinder).fit, BoxFit.contain);
      },
    );
  }

  testWidgets('enlarged date field shows the complete date at 360px', (
    tester,
  ) async {
    await pumpAmountForm(tester, width: 360, scale: 1.8);
    final field = find.descendant(
      of: find.byKey(const Key('expense-date-button')),
      matching: find.byType(RichText),
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(field);
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(1.8),
    )..layout(maxWidth: paragraph.size.width);
    expect(painter.computeLineMetrics(), hasLength(1));
    painter.dispose();
  });

  testWidgets('app theme does not fill or outline the budget amount field', (
    tester,
  ) async {
    await pumpBudget(tester);
    await tester.tap(find.text('예산 설정'));
    await tester.pumpAndSettle();
    final decorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('wallet-budget-input')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorator.decoration.filled, false);
    expect(decorator.decoration.enabledBorder, InputBorder.none);
    expect(decorator.decoration.focusedBorder, InputBorder.none);
    expect(decorator.decoration.disabledBorder, InputBorder.none);
  });

  testWidgets('app theme keeps expense amount white with a green underline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ExpenseFormBody(
            mode: ExpenseFormMode.add,
            initialData: ExpenseFormData.now(),
            petName: 'A',
            submitting: false,
            errorText: null,
            onSubmit: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final decorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('expense-amount-input')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorator.decoration.filled, false);
    expect(decorator.decoration.enabledBorder, isA<UnderlineInputBorder>());
  });

  testWidgets('monetary fields show grouped won with an adjacent suffix', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'wallet_monthly_budget_v2:alice:2025-02': 150000,
    });
    await pumpBudget(tester);
    await tester.tap(find.text('예산 설정'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('wallet-budget-input')),
    );
    expect(field.controller!.text, '150,000원');
    expect(field.decoration!.suffixText, isNull);
    await tester.enterText(
      find.byKey(const Key('wallet-budget-input')),
      '250000',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('wallet-budget-input')))
          .controller!
          .text,
      '250,000원',
    );
  });

  testWidgets(
    'empty expense field displays won and keypad formats saved digits',
    (tester) async {
      WalletTestApi([]);
      await forms.pumpForm(tester, singlePet: true);
      expect(find.text('0원'), findsOneWidget);
      await forms.enterAmount(tester, '32000');
      expect(find.text('32,000원'), findsOneWidget);
      await tester.tap(find.byKey(const Key('expense-category-food')));
      await forms.tapSave(tester);
      expect(find.text('wallet-home'), findsOneWidget);
    },
  );

  testWidgets('stale query pet falls back to the sole registered pet', (
    tester,
  ) async {
    final api = WalletTestApi([]);
    await forms.pumpForm(
      tester,
      singlePet: true,
      initialize: (container) {
        container.read(walletQueryProvider.notifier).setPet('removed-pet');
      },
    );
    await forms.enterAmount(tester, '800');
    await tester.tap(find.byKey(const Key('expense-category-food')));
    await forms.tapSave(tester);
    expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(api.rows.single['petId'], 'p1');
  });

  testWidgets('summary and budget fit the compact reference card at 390px', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'wallet_monthly_budget_v2:alice:2025-02': 10000,
    });
    await pumpBudget(tester);
    expect(
      tester.getSize(find.byType(WalletBudgetCard)).height,
      lessThanOrEqualTo(240),
    );
    expect(find.textContaining('전체 반려동물 기준 · 2월 사용 7,000원'), findsOneWidget);
  });

  testWidgets('budget validates range and remains reachable above keyboard', (
    tester,
  ) async {
    await pumpBudget(tester);
    await tester.tap(find.text('예산 설정'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    for (final entry in [
      ('', '예산 금액을 입력해 주세요.'),
      ('0', '예산은 0원보다 크게 입력해 주세요.'),
      ('-100', '예산은 0원보다 크게 입력해 주세요.'),
      ('1000000000', '예산 금액이 너무 커요. 1억 원 이하로 입력해 주세요.'),
      ('abc', '올바른 예산 금액을 입력해 주세요.'),
    ]) {
      await tester.ensureVisible(find.byKey(const Key('wallet-budget-input')));
      await tester.enterText(
        find.byKey(const Key('wallet-budget-input')),
        entry.$1,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('wallet-budget-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wallet-budget-save')));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'wallet_monthly_budget_v2:alice:2025-02',
        ),
        isNull,
      );
    }
    await tester.ensureVisible(find.byKey(const Key('wallet-budget-save')));
    expect(
      tester.getRect(find.byKey(const Key('wallet-budget-save'))).bottom,
      lessThanOrEqualTo(480),
    );
    expect(
      tester.getSize(find.byKey(const Key('wallet-budget-save'))).height,
      52,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'budget warns while typing above the limit and clears on correction',
    (tester) async {
      await pumpBudget(tester);
      await openBudget(tester);
      final input = find.byKey(const Key('wallet-budget-input'));
      await tester.enterText(input, '100000001');
      await tester.pumpAndSettle();
      expect(find.textContaining('1억 원 이하로 입력해 주세요.'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'wallet_monthly_budget_v2:alice:2025-02',
        ),
        isNull,
      );
      await tester.enterText(input, '100000000');
      await tester.pumpAndSettle();
      expect(find.textContaining('1억 원 이하로 입력해 주세요.'), findsNothing);
      await tester.tap(find.byKey(const Key('wallet-budget-save')));
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'wallet_monthly_budget_v2:alice:2025-02',
        ),
        100000000,
      );
    },
  );

  testWidgets('failed preference write retains old budget and permits retry', (
    tester,
  ) async {
    final store = BudgetStore({
      'flutter.wallet_monthly_budget_v2:alice:2025-02': 50000,
    });
    SharedPreferencesStorePlatform.instance = store;
    await pumpBudget(tester);
    await tester.tap(find.text('예산 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('wallet-budget-input')),
      '75000',
    );
    store.failWrites = true;
    await tester.ensureVisible(find.byKey(const Key('wallet-budget-save')));
    await tester.tap(find.byKey(const Key('wallet-budget-save')));
    await tester.pumpAndSettle();
    expect(find.text('예산을 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getInt(
        'wallet_monthly_budget_v2:alice:2025-02',
      ),
      50000,
    );
    store.failWrites = false;
    await tester.ensureVisible(find.byKey(const Key('wallet-budget-save')));
    await tester.tap(find.byKey(const Key('wallet-budget-save')));
    await tester.pumpAndSettle();
    expect(find.text('월 예산 75,000원'), findsOneWidget);
  });

  testWidgets(
    'pending save prevents duplicate writes and ignores logout completion',
    (tester) async {
      final store = BudgetStore({});
      SharedPreferencesStorePlatform.instance = store;
      final (_, auth) = await pumpBudget(tester);
      await tester.tap(find.text('예산 설정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('wallet-budget-input')),
        '100000000',
      );
      store.pending = Completer<void>();
      await tester.ensureVisible(find.byKey(const Key('wallet-budget-save')));
      await tester.tap(find.byKey(const Key('wallet-budget-save')));
      await tester.tap(find.byKey(const Key('wallet-budget-save')));
      await tester.pump();
      expect(store.writes, 1);
      auth.signOut();
      await tester.pumpAndSettle();
      store.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('계정이 변경되었어요. 예산 설정을 다시 열어 주세요.'), findsOneWidget);
      expect(find.text('100000000'), findsNothing);
      expect(store.writes, 1);
    },
  );

  testWidgets('load failure has retry and blocks saving until loaded', (
    tester,
  ) async {
    final store = BudgetStore({})..failReads = true;
    SharedPreferencesStorePlatform.instance = store;
    await pumpBudget(tester);
    expect(find.text('예산 설정을 불러오지 못했어요.'), findsOneWidget);
    store.failReads = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('월 예산을 설정해 지출을 관리해 보세요.'), findsOneWidget);
  });

  test(
    'migration retry after month rollover remains in original month',
    () async {
      var now = DateTime(2026, 9, 30);
      final store = BudgetStore({'flutter.wallet_monthly_budget': 50000})
        ..failIntWrites = true;
      SharedPreferencesStorePlatform.instance = store;
      final service = WalletBudgetService(now: () => now);
      await expectLater(
        service.load('alice', DateTime(2025, 2)),
        throwsStateError,
      );
      now = DateTime(2026, 10);
      store.failIntWrites = false;
      expect(await service.load('bob', now), isNull);
      expect(await service.load('alice', now), isNull);
      expect(await service.load('alice', DateTime(2026, 9)), 50000);
    },
  );

  testWidgets(
    'summary ignores category; budget includes all pets in selected month',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'wallet_monthly_budget_v2:alice:2025-02': 10000,
      });
      await pumpBudget(tester);
      expect(find.byKey(const Key('wallet-period-total')), findsOneWidget);
      expect(find.text('3,000원'), findsOneWidget);
      expect(find.textContaining('사용 7,000원'), findsOneWidget);
      expect(find.text('잔액 3,000원'), findsOneWidget);
      expect(find.text('2건의 지출'), findsOneWidget);
    },
  );

  testWidgets('unavailable selected total omits confirmed amount key', (
    tester,
  ) async {
    final (container, _) = await pumpBudget(tester, incomplete: true);
    container.read(walletQueryProvider.notifier).setPet(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-period-total')), findsNothing);
  });

  testWidgets('missing pet dataset never presents a partial budget sum', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'wallet_monthly_budget_v2:alice:2025-02': 10000,
    });
    await pumpBudget(tester, incomplete: true);
    expect(find.textContaining('사용 —'), findsOneWidget);
    expect(find.text('사용 3,000원'), findsNothing);
    expect(find.text('잔액 7,000원'), findsNothing);
  });

  testWidgets(
    'budget page freezes selected month, adds chips, saves and updates card',
    (tester) async {
      final (container, _) = await pumpBudget(tester);
      await tester.tap(find.text('예산 설정'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('2025년 2월 예산'), findsOneWidget);
      container.read(walletQueryProvider.notifier).setMonth(DateTime(2025, 3));
      await tester.tap(find.text('+1만원'));
      await tester.tap(find.text('+5만원'));
      await tester.tap(find.text('+10만원'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('wallet-budget-input')))
            .controller!
            .text,
        '160,000원',
      );
      await tester.ensureVisible(find.text('예산 저장'));
      await tester.tap(find.text('예산 저장'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('wallet_monthly_budget_v2:alice:2025-02'), 160000);
      expect(prefs.getInt('wallet_monthly_budget_v2:alice:2025-03'), isNull);
      container.read(walletQueryProvider.notifier).setMonth(DateTime(2025, 2));
      await tester.pumpAndSettle();
      expect(find.text('월 예산 160,000원'), findsOneWidget);
    },
  );

  testWidgets('legacy migrates only to current month and only one account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'wallet_monthly_budget': 50000});
    final (container, auth) = await pumpBudget(tester);
    expect(find.text('월 예산 50,000원'), findsNothing);
    container.read(walletQueryProvider.notifier).setPeriod(WalletPeriod.all);
    await tester.pumpAndSettle();
    expect(find.text('월 예산 50,000원'), findsOneWidget);
    auth.signIn('bob');
    await tester.pumpAndSettle();
    expect(find.text('월 예산 50,000원'), findsNothing);
    auth.signIn('alice');
    await tester.pumpAndSettle();
    expect(find.text('월 예산 50,000원'), findsOneWidget);
  });

  testWidgets('legacy preserves a current month value that already exists', (
    tester,
  ) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'wallet_monthly_budget': 50000,
      'wallet_monthly_budget_v2:alice:$month': 70000,
    });
    final (container, _) = await pumpBudget(tester);
    container.read(walletQueryProvider.notifier).setPeriod(WalletPeriod.year);
    await tester.pumpAndSettle();
    expect(find.text('월 예산 70,000원'), findsOneWidget);
  });

  testWidgets('account change blocks an open budget draft from saving', (
    tester,
  ) async {
    final (_, auth) = await pumpBudget(tester);
    await tester.tap(find.text('예산 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('wallet-budget-input')),
      '88888',
    );
    auth.signIn('bob');
    await tester.pumpAndSettle();
    expect(find.text('88888'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('wallet_monthly_budget_v2:bob:2025-02'), isNull);
  });

  testWidgets('form has compact selectable cards for every server category', (
    tester,
  ) async {
    WalletTestApi([]);
    await forms.pumpForm(tester, singlePet: true);
    await forms.enterAmount(tester, '123');
    for (final category in [
      'food',
      'snack',
      'hospital',
      'medicine',
      'grooming',
      'supplies',
      'etc',
    ]) {
      final finder = find.byKey(Key('expense-category-$category'));
      expect(tester.getSize(finder), const Size(62, 76));
      await tester.tap(finder);
      await tester.pump();
    }
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('expense-amount-input')))
          .style!
          .fontSize,
      32,
    );
    expect(find.text('얼마를 썼나요?'), findsOneWidget);
    expect(find.text('현재 시간으로 설정'), findsNothing);
    await forms.tapSave(tester);
    expect(find.text('wallet-home'), findsOneWidget);
  });
}

class BudgetStore extends InMemorySharedPreferencesStore {
  BudgetStore(super.data) : super.withData();
  bool failWrites = false, failIntWrites = false, failReads = false;
  Completer<void>? pending;
  int writes = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes++;
    await pending?.future;
    if (failWrites || (failIntWrites && valueType == 'Int')) return false;
    return super.setValue(valueType, key, value);
  }

  @override
  Future<Map<String, Object>> getAll() async {
    if (failReads) throw StateError('Preferences unavailable');
    return super.getAll();
  }
}

class BudgetAuth extends AuthNotifier {
  BudgetAuth() : super.test(stateFor('alice'));
  static AuthState stateFor(String id) => AuthState(
    isLoading: false,
    isAuthenticated: true,
    profile: UserProfile(id: id, email: '$id@test.local', nickname: id),
  );
  void signIn(String id) => state = stateFor(id);
  void signOut() =>
      state = const AuthState(isLoading: false, isAuthenticated: false);
}

class BudgetExpenses extends WalletExpenseNotifier {
  BudgetExpenses(Map<String, List<WalletExpense>> rows)
    : super(WalletExpenseService()) {
    state = state.copyWith(expensesByPet: rows);
  }
}

Future<(ProviderContainer, BudgetAuth)> pumpBudget(
  WidgetTester tester, {
  bool incomplete = false,
  PetNotifier? pets,
  WalletExpenseNotifier? wallet,
  double width = 390,
  double scale = 1,
  bool layoutFont = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = BudgetAuth();
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith((_) => auth),
      petProvider.overrideWith(
        (_) =>
            pets ??
            PetNotifier.test(
              PetState(
                isLoading: false,
                hasOnboarded: true,
                pets: [forms.pet('p1', 'A'), forms.pet('p2', 'B')],
                records: [],
                routines: [],
                todayRoutineItems: [],
                routineCompletions: {},
                quickTypeIds: [],
              ),
            ),
      ),
      walletExpenseProvider.overrideWith(
        (_) =>
            wallet ??
            BudgetExpenses({
              'p1': [
                WalletExpense.fromJson(
                  expenseJson('e1', 'p1', amount: 1000, date: '2025-02-01'),
                ),
                WalletExpense.fromJson({
                  ...expenseJson('e2', 'p1', amount: 2000, date: '2025-02-02'),
                  'category': 'snack',
                }),
                WalletExpense.fromJson(
                  expenseJson(
                    'current',
                    'p1',
                    amount: 900,
                    date: DateTime.now().toIso8601String().substring(0, 10),
                  ),
                ),
              ],
              if (!incomplete)
                'p2': [
                  WalletExpense.fromJson(
                    expenseJson('e3', 'p2', amount: 4000, date: '2025-02-01'),
                  ),
                ],
            }),
      ),
      walletQueryProvider.overrideWith(
        (_) => WalletQueryNotifier()
          ..setMonth(DateTime(2025, 2))
          ..setPet('p1')
          ..setCategory('food'),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: layoutFont ? amountTestTheme() : buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Consumer(
              builder: (context, ref, _) =>
                  WalletBudgetCard(data: ref.watch(walletViewProvider)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, auth);
}

Future<void> openBudget(WidgetTester tester) async {
  await tester.tap(find.text('예산 설정'));
  await tester.pumpAndSettle();
}

ThemeData amountTestTheme() => buildAppTheme().copyWith(
  textTheme: buildAppTheme().textTheme.apply(fontFamily: 'WalletLayoutTest'),
);

Future<void> pumpAmountForm(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: amountTestTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ExpenseFormBody(
          mode: ExpenseFormMode.add,
          initialData: ExpenseFormData.now(),
          petName: 'A',
          submitting: false,
          errorText: null,
          onSubmit: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void expectWholeAmount(WidgetTester tester, Key key, String expected) {
  final RenderEditable editable = tester
      .state<EditableTextState>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(EditableText),
        ),
      )
      .renderEditable;
  expect(editable.text!.toPlainText(), expected);
  expect(
    editable.maxScrollExtent,
    0,
    reason: 'The complete monetary span must fit after dismissal',
  );
  expect(editable.offset.pixels, 0);
  final boxes = editable.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: expected.length),
  );
  expect(boxes, isNotEmpty);
  for (final box in boxes) {
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(editable.size.width));
  }
}
