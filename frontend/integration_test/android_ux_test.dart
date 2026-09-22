// Writes only synthetic fixtures to the dedicated QA backend on port 8094.
// adb reverse tcp:8094 tcp:8094
// flutter test integration_test/android_ux_test.dart -d emulator-5554
//   --dart-define=ALLOW_ISOLATED_QA_WRITES=true
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/screens/wallet/expense_detail_screen.dart';
import 'package:frontend/screens/wallet/expense_edit_screen.dart';
import 'package:frontend/screens/wallet/expense_wallet_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native shell safety and isolated wallet save/failure/retry', (
    tester,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      fail(
        'This fixture writes local credentials and must run only on the QA Android emulator.',
      );
    }
    if (!const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES')) {
      fail(
        'Explicit isolated QA write opt-in required. Never run against user DB.',
      );
    }
    // Do not invoke production main: no Firebase/Kakao startup or push registration.
    initApiClient('http://127.0.0.1:8094');
    final random = Random.secure();
    final nonce =
        '${DateTime.now().microsecondsSinceEpoch}${random.nextInt(100000)}';
    await AuthService().register(
      email: 'ux-$nonce@example.invalid',
      password: List.generate(
        32,
        (_) => random.nextInt(16).toRadixString(16),
      ).join(),
      nickname: 'UX 테스트',
    );
    final pet = await PetService().createPet({
      'name': '검증용 반려동물',
      'species': 'dog',
      'birthDate': '2022-03-15',
    });
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
    final router = container.read(routerProvider);

    router.go('/my/profile');
    await _until(
      tester,
      () => find.byType(MyProfileScreen).evaluate().isNotEmpty,
    );
    await tester.enterText(find.byType(TextField).first, '임시 입력');
    await _hideKeyboard(tester);
    final homeTab = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('홈'),
    );
    await tester.tap(homeTab);
    await _until(tester, () => find.text('계속 입력').evaluate().isNotEmpty);
    await tester.tap(find.text('계속 입력'));
    await tester.pumpAndSettle();
    expect(find.text('임시 입력'), findsOneWidget);
    await tester.tap(homeTab);
    await _until(tester, () => find.text('나가기').evaluate().isNotEmpty);
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');

    router.go('/my/settings');
    await tester.pumpAndSettle();
    final homePoint = tester.getCenter(homeTab);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tapAt(homePoint);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/my/settings');
    if (find.text('취소').evaluate().isNotEmpty) {
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
    }
    expect(container.read(authProvider).isAuthenticated, isTrue);

    router.go('/wallet');
    await _until(
      tester,
      () => find.byType(ExpenseWalletScreen).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('wallet-add-button')));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('expense-amount-input')));
    for (final digit in '12000'.split('')) {
      await tester.tap(find.byKey(Key('record-number-key-$digit')));
      await tester.pump();
    }
    await _tap(tester, find.byKey(const Key('record-picker-done')));
    await _tap(tester, find.byKey(const Key('expense-category-food')));
    final item = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.key == const Key('expense-item-name-field'),
    );
    await tester.ensureVisible(item);
    await tester.enterText(item, '검증용 사료');
    await _hideKeyboard(tester);

    var writes = 0;
    var failNext = true;
    final failures = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.method == 'POST' &&
            request.path.endsWith('/wallet/expenses')) {
          writes++;
          if (failNext) {
            failNext = false;
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
        }
        handler.next(request);
      },
    );
    dio.interceptors.add(failures);
    addTearDown(() => dio.interceptors.remove(failures));
    final save = find.byKey(const Key('expense-save-button'));
    await _tap(tester, save);
    await _until(
      tester,
      () => find.byKey(const Key('expense-form-error')).evaluate().isNotEmpty,
    );
    expect(find.text('검증용 사료'), findsOneWidget);
    expect(await WalletExpenseService().listAllExpenses(pet.id), isEmpty);
    await _reveal(tester, save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await _until(
      tester,
      () => find.byType(ExpenseWalletScreen).evaluate().isNotEmpty,
    );
    final expenses = await WalletExpenseService().listAllExpenses(pet.id);
    expect(expenses, hasLength(1));
    expect(expenses.single.amount, 12000);
    expect(writes, 2); // One failed attempt, one persisted retry.
    await _tap(tester, find.text('검증용 사료'));
    await _until(
      tester,
      () => find.byType(ExpenseDetailScreen).evaluate().isNotEmpty,
    );
    await _tap(tester, find.byKey(const Key('expense-detail-edit-button')));
    await _until(
      tester,
      () => find.byType(ExpenseEditScreen).evaluate().isNotEmpty,
    );
    await _reveal(tester, item);
    await tester.enterText(item, '수정된 검증 사료');
    await _hideKeyboard(tester);
    await _tap(tester, save);
    await _until(
      tester,
      () => find.byType(ExpenseDetailScreen).evaluate().isNotEmpty,
    );
    expect(
      (await WalletExpenseService().getExpense(
        pet.id,
        expenses.single.id,
      )).itemName,
      '수정된 검증 사료',
    );
    await _tap(tester, find.byKey(const Key('expense-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await WalletExpenseService().listAllExpenses(pet.id), hasLength(1));
    expect(tester.takeException(), isNull);
    for (final route in [
      '/home',
      '/my',
      '/my/profile',
      '/my/settings',
      '/my/pets',
      '/wallet',
      '/wallet/calendar',
      '/wallet/report',
      '/records',
      '/records/meal/new',
      '/records/poop/new',
      '/routine',
      '/routine/schedule/new',
      '/community',
      '/community/search',
      '/community/write',
      '/notifications',
      '/my/inquiry',
    ]) {
      debugPrint('QA layout: $route');
      router.go(route);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, route);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Native route $route must fit the device and font scale.',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Native UI did not reach the expected state within 30 seconds.');
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final vertical = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(target, 180, scrollable: vertical.last);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
