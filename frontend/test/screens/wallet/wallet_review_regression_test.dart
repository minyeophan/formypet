import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/providers/wallet_view_provider.dart';
import 'package:frontend/screens/wallet/expense_calendar_screen.dart';
import 'package:frontend/screens/wallet/expense_detail_screen.dart';
import 'package:frontend/screens/wallet/expense_edit_screen.dart';
import 'package:frontend/screens/wallet/expense_form.dart';
import 'package:frontend/screens/wallet/expense_wallet_screen.dart';
import 'package:frontend/screens/wallet/wallet_expense_utils.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet_test_api.dart';

const recordError = '반려동물 기록을 불러오지 못했어요. 다시 시도해 주세요.';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'ambiguous populated error recovers through real pet refresh and data retry without changing query',
    (tester) async {
      const ambiguousError = '반려동물 정보를 불러오지 못했어요. 다시 시도해 주세요.';
      final api = PetRecoveryApi([expenseJson('e1', 'p1')]);
      final pets = PetNotifier.test(petState(error: ambiguousError));
      final (container, _) = await pumpReview(tester, pets: pets);
      final query = container.read(walletQueryProvider.notifier);
      query.setPet('p1');
      query.setPeriod(WalletPeriod.year);
      query.setMonth(DateTime(2026, 4));
      query.setCategory('food');
      await tester.pumpAndSettle();

      // Real refreshPets intentionally preserves the error when the active pet
      // remains. Keep records pending so the UI must wait for the follow-up retry.
      final recordsPending = Completer<void>();
      api.recordsGate = recordsPending.future;
      await tester.tap(find.text('반려동물 새로고침'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.requests.where((r) => r.path == '/api/v1/pets'), hasLength(1));
      expect(container.read(petProvider).isLoading, isTrue);
      expect(container.read(walletViewProvider).available, isFalse);
      expect(api.requests.where((r) => r.path.contains('/wallet/')), isEmpty);

      recordsPending.complete();
      await tester.pumpAndSettle();
      expect(container.read(petProvider).dataErrorText, isNull);
      expect(container.read(walletViewProvider).available, isTrue);
      expect(find.text('반려동물 목록을 불러오지 못했어요.'), findsNothing);
      expect(find.text('1,000원'), findsWidgets);
      expect(
        api.requests.where((r) => r.path == '/api/v1/pets/p1/records'),
        hasLength(1),
      );
      expect(container.read(walletQueryProvider).petId, 'p1');
      expect(container.read(walletQueryProvider).period, WalletPeriod.year);
      expect(container.read(walletQueryProvider).baseMonth, DateTime(2026, 4));
      expect(container.read(walletQueryProvider).category, 'food');
      expect(container.read(petProvider).activePetId, 'p1');
    },
  );

  testWidgets('failed pet-list retry keeps ambiguous cached error blocked', (
    tester,
  ) async {
    final api = PetRecoveryApi([expenseJson('e1', 'p1')])..petListFails = true;
    final pets = PetNotifier.test(
      petState(error: '반려동물 정보를 불러오지 못했어요. 다시 시도해 주세요.'),
    );
    final (container, _) = await pumpReview(tester, pets: pets);
    await tester.tap(find.text('반려동물 새로고침'));
    await tester.pumpAndSettle();
    expect(container.read(walletViewProvider).available, isFalse);
    expect(find.text('반려동물 목록을 불러오지 못했어요.'), findsOneWidget);
    expect(api.requests, isNotEmpty);
    expect(api.requests.map((r) => r.path), everyElement('/api/v1/pets'));
  });

  testWidgets(
    'wallet revalidates at 60 seconds on return and keeps younger cache',
    (tester) async {
      var now = DateTime(2026, 9, 8);
      final api = WalletTestApi([expenseJson('e1', 'p1')]);
      final wallet = WalletExpenseNotifier(
        WalletExpenseService(),
        now: () => now,
      );
      final (_, router) = await pumpReview(tester, wallet: wallet);
      unawaited(router.push('/other'));
      await tester.pumpAndSettle();
      api.rows.add(expenseJson('e2', 'p1', amount: 2000));
      now = now.add(const Duration(seconds: 59));
      router.pop();
      await tester.pumpAndSettle();
      expect(
        api.requests.where((r) => r.path.endsWith('/expenses')),
        hasLength(1),
      );
      expect(find.text('1,000원'), findsWidgets);
      unawaited(router.push('/other'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 1));
      router.pop();
      await tester.pumpAndSettle();
      expect(
        api.requests.where((r) => r.path.endsWith('/expenses')),
        hasLength(2),
      );
      expect(find.text('3,000원'), findsWidgets);
    },
  );

  test(
    'stale concurrent ensure calls coalesce and old session completion cannot refill cache',
    () async {
      var now = DateTime(2026, 9, 8);
      final api = WalletTestApi([expenseJson('e1', 'p1')]);
      final wallet = WalletExpenseNotifier(
        WalletExpenseService(),
        now: () => now,
      );
      addTearDown(wallet.dispose);
      await wallet.ensureAllPets(['p1']);
      now = now.add(const Duration(seconds: 60));
      final pending = Completer<void>();
      final started = Completer<void>();
      api.beforeResponse = (_) async {
        if (!started.isCompleted) started.complete();
        await pending.future;
      };
      final a = wallet.ensureAllPets(['p1']);
      final b = wallet.ensureAllPets(['p1']);
      // Failure here proves a stale cache incorrectly bypasses revalidation.
      await Future.any<void>([
        started.future,
        Future.wait([a, b]).then((_) {}),
      ]);
      expect(
        api.requests.where((r) => r.path.endsWith('/expenses')),
        hasLength(2),
      );
      await started.future;
      wallet.resetSession(authenticated: true);
      pending.complete();
      await Future.wait([a, b]);
      expect(wallet.state.expensesByPet, isEmpty);
      api.beforeResponse = null;
      await wallet.ensureAllPets(['p1']);
      expect(
        api.requests.where((r) => r.path.endsWith('/expenses')),
        hasLength(3),
      );
    },
  );

  testWidgets(
    'record errors do not block a known pet wallet but loading still waits',
    (tester) async {
      final api = WalletTestApi([expenseJson('e1', 'p1')]);
      final pets = TestPets(petState(error: recordError, loading: true));
      final (container, _) = await pumpReview(
        tester,
        pets: pets,
        settle: false,
      );
      expect(container.read(walletViewProvider).available, isFalse);
      expect(api.requests, isEmpty);
      pets.publish(petState(error: recordError));
      await tester.pumpAndSettle();
      expect(container.read(walletViewProvider).available, isTrue);
      expect(find.text('1,000원'), findsWidgets);
      expect(find.text('반려동물 목록을 불러오지 못했어요.'), findsNothing);
      expect(
        api.requests.where((r) => r.path.endsWith('/expenses')),
        hasLength(1),
      );
    },
  );

  for (final empty in [false, true]) {
    testWidgets(
      'ambiguous pet-list failure remains blocked with empty=$empty',
      (tester) async {
        final api = WalletTestApi([expenseJson('e1', 'p1')]);
        final (container, _) = await pumpReview(
          tester,
          pets: TestPets(
            petState(error: '반려동물 정보를 불러오지 못했어요. 다시 시도해 주세요.', empty: empty),
          ),
        );
        expect(container.read(walletViewProvider).available, isFalse);
        expect(find.text('반려동물 목록을 불러오지 못했어요.'), findsOneWidget);
        expect(api.requests, isEmpty);
      },
    );
  }

  testWidgets(
    'calendar retains browsed date on remount and pet or category changes',
    (tester) async {
      WalletTestApi([]);
      final (container, router) = await pumpReview(
        tester,
        location: '/wallet/calendar',
      );
      final query = container.read(walletQueryProvider.notifier);
      query.selectDate(DateTime(2026, 6, 17));
      router.go('/wallet');
      await tester.pumpAndSettle();
      query.setPet('p1');
      query.setCategory('food');
      router.go('/wallet/calendar');
      await tester.pumpAndSettle();
      expect(
        container.read(walletQueryProvider).calendarMonth,
        DateTime(2026, 6),
      );
      expect(
        container.read(walletQueryProvider).selectedDate,
        DateTime(2026, 6, 17),
      );
      router.go('/wallet');
      await tester.pumpAndSettle();
      query.setMonth(DateTime(2026, 4));
      router.go('/wallet/calendar');
      await tester.pumpAndSettle();
      expect(
        container.read(walletQueryProvider).calendarMonth,
        DateTime(2026, 4),
      );
      query.reset();
      query.selectDate(DateTime(2026, 2, 4));
      query.openCalendar();
      expect(
        container.read(walletQueryProvider).calendarMonth,
        DateTime(2026, 9),
      );
    },
  );

  testWidgets(
    'calendar pet-only entry preserves the originating year period and browsed date',
    (tester) async {
      WalletTestApi([]);
      final (container, router) = await pumpReview(tester);
      final query = container.read(walletQueryProvider.notifier);
      query.setPeriod(WalletPeriod.year);
      query.openCalendar();
      query.selectDate(DateTime(2026, 3, 19));
      router.go('/wallet/calendar?petId=p1');
      await tester.pumpAndSettle();
      expect(container.read(walletQueryProvider).period, WalletPeriod.year);
      expect(
        container.read(walletQueryProvider).selectedDate,
        DateTime(2026, 3, 19),
      );
    },
  );

  testWidgets(
    'successful wallet exposes refresh and error state has only one refresh',
    (tester) async {
      final api = WalletTestApi([expenseJson('e1', 'p1')]);
      await pumpReview(tester);
      expect(find.widgetWithText(TextButton, '새로고침'), findsOneWidget);
      api.rows.add(expenseJson('e2', 'p1', amount: 2000));
      await tester.tap(find.widgetWithText(TextButton, '새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('3,000원'), findsWidgets);
      api.listFails = true;
      await tester.tap(find.widgetWithText(TextButton, '새로고침'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, '새로고침'), findsOneWidget);
      expect(find.text('3,000원'), findsWidgets);
    },
  );

  testWidgets(
    'edit keeps mounted draft through pet loading and disables save until ready',
    (tester) async {
      final api = WalletTestApi([expenseJson('e1', 'p1')]);
      final pets = TestPets(petState());
      await pumpReview(
        tester,
        pets: pets,
        location: '/wallet/expenses/e1/edit?petId=p1',
      );
      await tester.enterText(find.byType(TextField).last, 'unsaved memo');
      final form = tester.state(find.byType(ExpenseFormBody));
      pets.publish(petState(loading: true));
      await tester.pump();
      expect(find.byType(ExpenseFormBody), findsOneWidget);
      expect(tester.state(find.byType(ExpenseFormBody)), same(form));
      await tester.ensureVisible(find.byKey(const Key('expense-save-button')));
      await tester.tap(find.byKey(const Key('expense-save-button')));
      await tester.pump();
      expect(api.requests.where((r) => r.method == 'PUT'), isEmpty);
      pets.publish(petState());
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'unsaved memo',
      );
      await tester.tap(find.byKey(const Key('expense-save-button')));
      await tester.pumpAndSettle();
      expect(
        api.requests.singleWhere((r) => r.method == 'PUT').data,
        containsPair('note', 'unsaved memo'),
      );
    },
  );

  testWidgets('wallet back from direct entry goes home', (tester) async {
    WalletTestApi([]);
    await pumpReview(tester);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('detail deletion returns to wallet whose back goes home', (
    tester,
  ) async {
    WalletTestApi([expenseJson('e1', 'p1')]);
    await pumpReview(tester, location: '/wallet/expenses/e1?petId=p1');
    await tester.tap(find.byKey(const Key('expense-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-delete-confirm-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseWalletScreen), findsOneWidget);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.text('home-screen'), findsOneWidget);
  });
}

class TestPets extends PetNotifier {
  TestPets(super.initialState) : super.test();
  void publish(PetState next) => state = next;
}

/// Extend only the HTTP boundary; PetNotifier and all service methods are real.
class PetRecoveryApi extends WalletTestApi {
  PetRecoveryApi(super.rows);
  Future<void>? recordsGate;
  bool petListFails = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.contains('/wallet/')) {
      return super.fetch(options, requestStream, cancelFuture);
    }
    requests.add(options);
    Object? data;
    var status = 200;
    switch (path) {
      case '/api/v1/pets':
        status = petListFails ? 500 : 200;
        data = [
          for (final pet in petState().pets) {'id': pet.id, ...pet.toJson()},
        ];
      case '/api/v1/pets/p1/records':
        await recordsGate;
        data = [];
      case '/api/v1/pets/p1/routines':
        data = [];
      case '/api/v1/pets/p1/routines/today':
        data = {
          'routines': [],
          'summary': {'total': 0, 'done': 0, 'rate': 0.0},
        };
      default:
        throw StateError('Unexpected pet recovery request: $path');
    }
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

PetState petState({bool loading = false, String? error, bool empty = false}) =>
    PetState(
      isLoading: loading,
      dataErrorText: error,
      hasOnboarded: true,
      pets: empty
          ? []
          : [
              const Pet(
                id: 'p1',
                name: 'A',
                species: 'dog',
                birthDate: '2022-03-15',
                accentColor: '#F4A460',
                bgLight: '#FFF8F0',
              ),
            ],
      activePetId: 'p1',
      records: [],
      routines: [],
      todayRoutineItems: [],
      routineCompletions: {},
      quickTypeIds: [],
    );

Future<(ProviderContainer, GoRouter)> pumpReview(
  WidgetTester tester, {
  PetNotifier? pets,
  String location = '/wallet',
  bool settle = true,
  WalletExpenseNotifier? wallet,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      petProvider.overrideWith((_) => pets ?? TestPets(petState())),
      walletExpenseProvider.overrideWith(
        (_) => wallet ?? WalletExpenseNotifier(WalletExpenseService()),
      ),
      walletQueryProvider.overrideWith(
        (_) => WalletQueryNotifier(now: () => DateTime(2026, 9, 8)),
      ),
    ],
  );
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home-screen')),
      ),
      GoRoute(
        path: '/other',
        builder: (_, _) => const Scaffold(body: Text('other-screen')),
      ),
      GoRoute(path: '/wallet', builder: (_, _) => const ExpenseWalletScreen()),
      GoRoute(
        path: '/wallet/calendar',
        builder: (_, state) => ExpenseCalendarScreen(
          petId: state.uri.queryParameters['petId'],
          category: state.uri.queryParameters['category'],
          period: state.uri.queryParameters['period'],
        ),
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
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (container, router);
}
