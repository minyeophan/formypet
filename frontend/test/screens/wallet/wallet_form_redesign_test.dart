import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/screens/wallet/expense_add_screen.dart';
import 'package:frontend/screens/wallet/expense_detail_screen.dart';
import 'package:frontend/screens/wallet/expense_edit_screen.dart';
import 'package:frontend/widgets/app_visual.dart';
import 'package:frontend/widgets/record_inputs/record_inputs.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'wallet_test_api.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'add snapshots wallet pet instead of active pet and pops to caller',
    (tester) async {
      final api = WalletTestApi([]);
      final (container, router) = await pumpForm(
        tester,
        location: '/origin',
        initialize: (container) {
          container.read(walletQueryProvider.notifier).setPet('p2');
        },
      );
      unawaited(router.push('/wallet/expenses/new'));
      await tester.pumpAndSettle();
      await enterAmount(tester, '9900');
      await tester.tap(find.byKey(const Key('expense-category-food')));
      container.read(walletQueryProvider.notifier).setPet('p1');
      await tester.pumpAndSettle();
      await tapSave(tester);
      expect(
        api.requests.singleWhere((r) => r.method == 'POST').path,
        '/api/v1/pets/p2/wallet/expenses',
      );
      expect(container.read(petProvider).activePetId, 'p1');
      expect(find.text('origin'), findsOneWidget);
    },
  );

  testWidgets('all with one pet automatically selects its owner', (
    tester,
  ) async {
    final api = WalletTestApi([]);
    await pumpForm(tester, singlePet: true);
    await enterAmount(tester, '1');
    await tester.tap(find.byKey(const Key('expense-category-food')));
    await tapSave(tester);
    expect(
      api.requests.singleWhere((r) => r.method == 'POST').path,
      '/api/v1/pets/p1/wallet/expenses',
    );
  });

  testWidgets(
    'session reset clears local owner and draft and ignores pending save completion',
    (tester) async {
      final pending = Completer<void>();
      final api = WalletTestApi([])
        ..beforeResponse = (request) async {
          if (request.method == 'POST') await pending.future;
        };
      final (container, _) = await pumpForm(tester);
      await tester.tap(find.byKey(const Key('expense-pet-p2')));
      await enterAmount(tester, '500');
      await tester.tap(find.byKey(const Key('expense-category-food')));
      await tester.enterText(find.byType(TextField).last, 'old session');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('expense-save-button')));
      await tester.tap(find.byKey(const Key('expense-save-button')));
      await tester.tap(find.byKey(const Key('expense-save-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
      container
          .read(walletExpenseProvider.notifier)
          .resetSession(authenticated: true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RecordNumberInput>(find.byType(RecordNumberInput))
            .controller
            .text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('expense-pet-p2')))
            .selected,
        isFalse,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseAddScreen), findsOneWidget);
      expect(find.text('wallet-home'), findsNothing);
    },
  );

  testWidgets('save failure retains draft for a successful explicit retry', (
    tester,
  ) async {
    final api = WalletTestApi([])..mutationFails = true;
    await pumpForm(tester, singlePet: true);
    await enterAmount(tester, '999999999');
    await tester.tap(find.byKey(const Key('expense-category-food')));
    await tester.enterText(find.byType(TextField).last, 'retry memo');
    await tapSave(tester);
    expect(find.byKey(const Key('expense-form-error')), findsOneWidget);
    expect(
      tester
          .widget<RecordNumberInput>(find.byType(RecordNumberInput))
          .controller
          .text,
      '999999999',
    );
    api.mutationFails = false;
    await tapSave(tester);
    expect(api.requests.where((r) => r.method == 'POST'), hasLength(2));
    expect(api.rows.single['note'], 'retry memo');
    expect(find.text('wallet-home'), findsOneWidget);
  });

  testWidgets('removed selected owner cannot receive the existing draft', (
    tester,
  ) async {
    final api = WalletTestApi([]);
    final (container, _) = await pumpForm(tester);
    await tester.tap(find.byKey(const Key('expense-pet-p2')));
    await enterAmount(tester, '100');
    await tester.tap(find.byKey(const Key('expense-category-food')));
    await container.read(petProvider.notifier).clearForSignedOutUser();
    await tester.pumpAndSettle();
    await tapSave(tester);
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets(
    'edit clears nullable fields and pops with original owner despite global selection',
    (tester) async {
      final api = WalletTestApi([
        {...expenseJson('e1', 'p2'), 'note': 'old memo'},
      ]);
      final (container, router) = await pumpForm(tester, location: '/origin');
      unawaited(router.push('/wallet/expenses/e1/edit?petId=p2'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.enterText(find.byType(TextField).last, '');
      await tapSave(tester);
      final put = api.requests.singleWhere((r) => r.method == 'PUT');
      expect(put.path, '/api/v1/pets/p2/wallet/expenses/e1');
      expect(put.data, containsPair('itemName', null));
      expect(put.data, containsPair('note', null));
      expect(put.data, containsPair('currency', 'KRW'));
      expect(container.read(petProvider).activePetId, 'p1');
      expect(find.text('origin'), findsOneWidget);
    },
  );

  testWidgets(
    'delete requires confirmation and disables edit and repeated deletion while busy',
    (tester) async {
      final pending = Completer<void>();
      final api = WalletTestApi([expenseJson('e1', 'p2')])
        ..beforeResponse = (request) async {
          if (request.method == 'DELETE') await pending.future;
        };
      await pumpForm(tester, location: '/wallet/expenses/e1?petId=p2');
      await tester.tap(find.byKey(const Key('expense-delete-button')));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tester.tap(find.byKey(const Key('expense-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense-delete-confirm-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('expense-detail-edit-button')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('expense-delete-button')));
      await tester.pump();
      expect(api.requests.where((r) => r.method == 'DELETE'), hasLength(1));
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('wallet-home'), findsOneWidget);
    },
  );

  testWidgets(
    'delete confirmation from an old session cannot mutate the new session',
    (tester) async {
      final api = WalletTestApi([expenseJson('e1', 'p2')]);
      final (container, _) = await pumpForm(
        tester,
        location: '/wallet/expenses/e1?petId=p2',
      );
      await tester.tap(find.byKey(const Key('expense-delete-button')));
      await tester.pumpAndSettle();
      container
          .read(walletExpenseProvider.notifier)
          .resetSession(authenticated: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expense-delete-confirm-button')));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );

  testWidgets('save remains reachable above keyboard on a small screen', (
    tester,
  ) async {
    WalletTestApi([]);
    await pumpForm(tester, singlePet: true);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('expense-save-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('expense-save-button')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const Key('expense-save-button')));
    expect(rect.bottom, lessThanOrEqualTo(544));
    expect(rect.height, 52);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all pets requires explicit owner and preserves draft when switched',
    (tester) async {
      final api = WalletTestApi([]);
      final (container, _) = await pumpForm(tester);
      await enterAmount(tester, '12000');
      await tester.tap(find.byKey(const Key('expense-category-food')));
      await tester.enterText(find.byType(TextField).last, 'keep this memo');
      await tapSave(tester);
      expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.ensureVisible(find.byKey(const Key('expense-pet-p2')));
      await tester.tap(find.byKey(const Key('expense-pet-p2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RecordNumberInput>(find.byType(RecordNumberInput))
            .controller
            .text,
        '12000',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'keep this memo',
      );
      await tester.tap(find.byKey(const Key('expense-pet-p1')));
      await tester.tap(find.byKey(const Key('expense-pet-p2')));
      await tapSave(tester);
      final post = api.requests.singleWhere((r) => r.method == 'POST');
      expect(post.path, '/api/v1/pets/p2/wallet/expenses');
      expect(post.data, containsPair('note', 'keep this memo'));
      expect(post.data, containsPair('amount', 12000));
      expect(container.read(petProvider).activePetId, 'p1');
    },
  );

  testWidgets(
    'form starts with amount then pet then category and uses category visuals',
    (tester) async {
      WalletTestApi([]);
      await pumpForm(tester);
      expect(
        tester.getTopLeft(find.byKey(const Key('expense-amount-input'))).dy,
        lessThan(tester.getTopLeft(find.text('반려동물')).dy),
      );
      expect(
        tester.getTopLeft(find.text('반려동물')).dy,
        lessThan(tester.getTopLeft(find.text('카테고리')).dy),
      );
      expect(
        tester.getTopLeft(find.text('카테고리')).dy,
        lessThan(tester.getTopLeft(find.text('날짜/시간')).dy),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('expense-category-food')),
          matching: find.byType(AppVisual),
        ),
        findsOneWidget,
      );
    },
  );

  for (final edit in [false, true]) {
    testWidgets('${edit ? 'edit' : 'detail'} reports a real 404 as missing', (
      tester,
    ) async {
      WalletTestApi([]);
      await pumpForm(
        tester,
        location: '/wallet/expenses/missing${edit ? '/edit' : ''}?petId=p2',
      );
      expect(find.byKey(const Key('expense-detail-not-found')), findsOneWidget);
      expect(find.byKey(const Key('expense-load-error')), findsNothing);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets(
      '${edit ? 'edit' : 'detail'} distinguishes network error from missing expense and retries',
      (tester) async {
        final api = WalletTestApi([expenseJson('e1', 'p2')]);
        api.beforeResponse = (request) async {
          if (request.method == 'GET') {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            );
          }
        };
        await pumpForm(
          tester,
          location: '/wallet/expenses/e1${edit ? '/edit' : ''}?petId=p2',
        );
        expect(find.byKey(const Key('expense-detail-not-found')), findsNothing);
        expect(find.text('다시 시도'), findsOneWidget);
        api.beforeResponse = null;
        await tester.tap(find.text('다시 시도'));
        await tester.pumpAndSettle();
        expect(find.text('B'), findsOneWidget);
      },
    );

    testWidgets(
      '${edit ? 'edit' : 'detail'} waits for pets before declaring owner missing',
      (tester) async {
        WalletTestApi([expenseJson('e1', 'p2')]);
        await pumpForm(
          tester,
          location: '/wallet/expenses/e1${edit ? '/edit' : ''}?petId=p2',
          loadingPets: true,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byKey(const Key('expense-detail-not-found')), findsNothing);
      },
    );
  }

  testWidgets(
    'detail presents category amount hero and read only owner date memo',
    (tester) async {
      final api = WalletTestApi([
        {
          ...expenseJson('e1', 'p2', date: '2026-09-08'),
          'note': 'read only memo',
        },
      ]);
      final (container, _) = await pumpForm(
        tester,
        location: '/wallet/expenses/e1?petId=p2',
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(RecordNumberInput), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('read only memo'), findsOneWidget);
      expect(find.byType(AppVisual), findsWidgets);
      expect(
        tester.getTopLeft(find.text('1,000원')).dy,
        lessThan(tester.getTopLeft(find.text('반려동물')).dy),
      );
      expect(container.read(petProvider).activePetId, 'p1');
      expect(api.requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );
}

Future<(ProviderContainer, GoRouter)> pumpForm(
  WidgetTester tester, {
  String location = '/wallet/expenses/new',
  bool loadingPets = false,
  bool singlePet = false,
  void Function(ProviderContainer)? initialize,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      petProvider.overrideWith(
        (_) => PetNotifier.test(
          PetState(
            isLoading: loadingPets,
            hasOnboarded: true,
            pets: loadingPets
                ? []
                : [pet('p1', 'A'), if (!singlePet) pet('p2', 'B')],
            activePetId: 'p1',
            records: [],
            routines: [],
            todayRoutineItems: [],
            routineCompletions: {},
            quickTypeIds: [],
          ),
        ),
      ),
      walletExpenseProvider.overrideWith(
        (_) => WalletExpenseNotifier(WalletExpenseService()),
      ),
      walletQueryProvider.overrideWith((_) => WalletQueryNotifier()),
    ],
  );
  addTearDown(container.dispose);
  initialize?.call(container);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/wallet',
        builder: (_, _) => const Scaffold(body: Text('wallet-home')),
      ),
      GoRoute(
        path: '/origin',
        builder: (_, _) => const Scaffold(body: Text('origin')),
      ),
      GoRoute(
        path: '/wallet/expenses/new',
        builder: (_, _) => const ExpenseAddScreen(),
      ),
      GoRoute(
        path: '/wallet/expenses/:id/edit',
        builder: (_, state) => ExpenseEditScreen(
          expenseId: state.pathParameters['id']!,
          petId: state.uri.queryParameters['petId'],
        ),
      ),
      GoRoute(
        path: '/wallet/expenses/:id',
        builder: (_, state) => ExpenseDetailScreen(
          expenseId: state.pathParameters['id']!,
          petId: state.uri.queryParameters['petId'],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (loadingPets) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return (container, router);
}

Pet pet(String id, String name) => Pet(
  id: id,
  name: name,
  species: 'dog',
  birthDate: '2022-03-15',
  accentColor: '#F4A460',
  bgLight: '#FFF8F0',
);

Future<void> enterAmount(WidgetTester tester, String digits) async {
  await tester.ensureVisible(find.byKey(const Key('expense-amount-input')));
  await tester.tap(find.byKey(const Key('expense-amount-input')));
  await tester.pumpAndSettle();
  for (final digit in digits.split('')) {
    await tester.tap(find.byKey(Key('record-number-key-$digit')));
  }
  await tester.tap(find.byKey(const Key('record-picker-done')));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('expense-save-button')));
  await tester.tap(find.byKey(const Key('expense-save-button')));
  await tester.pumpAndSettle();
}
