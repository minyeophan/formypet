import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/care_schedule.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/wallet_expense.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/auth/auth_screen.dart';
import 'package:frontend/screens/community/community_screen.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/screens/my/my_inquiry_screen.dart';
import 'package:frontend/screens/my/my_notices_screen.dart';
import 'package:frontend/screens/my/my_pets_screen.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/screens/my/my_settings_screen.dart';
import 'package:frontend/screens/my/my_support_center_screen.dart';
import 'package:frontend/screens/onboarding/onboarding_screen.dart';
import 'package:frontend/screens/wallet/expense_add_screen.dart';
import 'package:frontend/screens/wallet/expense_detail_screen.dart';
import 'package:frontend/screens/wallet/expense_edit_screen.dart';
import 'package:frontend/screens/wallet/expense_report_screen.dart';
import 'package:frontend/screens/wallet/expense_wallet_screen.dart';
import 'package:frontend/screens/records/record_category_form_screen.dart';
import 'package:frontend/screens/records/records_screen.dart';
import 'package:frontend/screens/routine/routine_create_screen.dart';
import 'package:frontend/screens/routine/routine_schedule_create_screen.dart';
import 'package:frontend/screens/splash/splash_screen.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:frontend/widgets/app_text.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('/ renders splash while app state is loading', (tester) async {
    await _pumpRouter(
      tester,
      authState: const AuthState(isLoading: true, isAuthenticated: false),
      petState: _petState(isLoading: true, hasOnboarded: false),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('completed unauthenticated state redirects to /auth', (
    tester,
  ) async {
    await _pumpRouter(
      tester,
      authState: const AuthState(isLoading: false, isAuthenticated: false),
      petState: _petState(isLoading: false, hasOnboarded: false),
    );

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('authenticated user without pets redirects to /onboarding', (
    tester,
  ) async {
    await _pumpRouter(
      tester,
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(isLoading: false, hasOnboarded: false),
    );

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('authenticated user with pets redirects to /home', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('/pets/new is available for authenticated users with pets', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/pets/new',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    final screen = tester.widget<OnboardingScreen>(
      find.byType(OnboardingScreen),
    );
    expect(screen.mode, PetEntryMode.additionalPet);
  });

  testWidgets('/records?tab=growth redirects to growth route', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/records?tab=growth',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    expect(find.byType(RecordsScreen), findsNothing);
    expect(find.byType(GrowthRecordsScreen), findsOneWidget);
  });

  testWidgets('/records valid date query selects that date', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/records?date=2026-05-09',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    expect(
      find.byKey(const Key('records-calendar-day-2026-05-09')),
      findsOneWidget,
    );
    final label = tester.widget<AppText>(
      find
          .descendant(
            of: find.byKey(const Key('records-selected-date')),
            matching: find.byType(AppText),
          )
          .first,
    );
    expect(label.text, contains('5'));
    expect(label.text, contains('9'));
  });

  testWidgets('record form routes use valid date query', (tester) async {
    final pet = _pet('1');
    final petState = _petState(
      isLoading: false,
      hasOnboarded: true,
      pets: [pet],
      activePetId: pet.id,
    );

    await _pumpRouter(
      tester,
      initialLocation: '/records/meal/new?date=2026-05-09',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: petState,
    );
    expect(find.byKey(const Key('meal-date-label')), findsOneWidget);
    expect(find.text('2026-05-09'), findsOneWidget);

    await _pumpRouter(
      tester,
      initialLocation: '/records/water/new?date=2026-05-09',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: petState,
    );
    expect(find.byKey(const Key('category-date-label')), findsOneWidget);
    expect(find.text('2026-05-09'), findsOneWidget);
  });

  testWidgets(
    'record form routes fallback to today for missing or invalid date query',
    (tester) async {
      final pet = _pet('1');
      final petState = _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      );

      await _pumpRouter(
        tester,
        initialLocation: '/records/meal/new',
        authState: const AuthState(isLoading: false, isAuthenticated: true),
        petState: petState,
      );
      expect(find.text(_todayIso()), findsOneWidget);

      await _pumpRouter(
        tester,
        initialLocation: '/records/meal/new?date=2026-02-30',
        authState: const AuthState(isLoading: false, isAuthenticated: true),
        petState: petState,
      );
      expect(find.text(_todayIso()), findsOneWidget);
    },
  );

  testWidgets('/records/meal/new opens meal record screen', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/records/meal/new',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    expect(find.text('급식 기록'), findsOneWidget);
    expect(find.text('사료 종류'), findsOneWidget);
  });

  testWidgets('/wallet opens keeper wallet actions', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/wallet',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );
    expect(find.byType(ExpenseWalletScreen), findsOneWidget);
  });

  testWidgets('/wallet/report opens expense report', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/wallet/report',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );
    expect(find.byType(ExpenseReportScreen), findsOneWidget);
  });

  testWidgets('/wallet expense routes open CRUD screens', (tester) async {
    final pet = _pet('1');
    final petState = _petState(
      isLoading: false,
      hasOnboarded: true,
      pets: [pet],
      activePetId: pet.id,
    );

    await _pumpRouter(
      tester,
      initialLocation: '/wallet/expenses/new',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: petState,
    );
    expect(find.byType(ExpenseAddScreen), findsOneWidget);

    await _pumpRouter(
      tester,
      initialLocation: '/wallet/expenses/expense-1',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: petState,
    );
    expect(find.byType(ExpenseDetailScreen), findsOneWidget);

    await _pumpRouter(
      tester,
      initialLocation: '/wallet/expenses/expense-1/edit',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: petState,
    );
    expect(find.byType(ExpenseEditScreen), findsOneWidget);
  });

  testWidgets('home wallet menu opens wallet route', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/home',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    await tester.tap(find.byIcon(Icons.account_balance_wallet_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseWalletScreen), findsOneWidget);
  });

  testWidgets('wallet actions open expense add and report routes', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/wallet',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseAddScreen), findsOneWidget);

    await _pumpRouter(
      tester,
      initialLocation: '/wallet',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    await tester.tap(find.byIcon(Icons.receipt_long_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseReportScreen), findsOneWidget);
  });

  testWidgets('wallet direct URL back buttons use wallet fallback', (
    tester,
  ) async {
    final pet = _pet('1');
    final petState = _petState(
      isLoading: false,
      hasOnboarded: true,
      pets: [pet],
      activePetId: pet.id,
    );

    for (final path in ['/wallet/report', '/wallet/expenses/new']) {
      await _pumpRouter(
        tester,
        initialLocation: path,
        authState: const AuthState(isLoading: false, isAuthenticated: true),
        petState: petState,
      );

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseWalletScreen), findsOneWidget, reason: path);
    }
  });

  testWidgets(
    'record form back dismisses keyboard before direct URL fallback',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pet = _pet('1');

      for (final entry in {
        '/records/meal/new': (
          field: const Key('meal-product-field'),
          fallback: 'Pet 1의 반려기록',
        ),
        '/records/walk/new': (
          field: const Key('category-note-field'),
          fallback: 'Pet 1의 반려기록',
        ),
      }.entries) {
        await _pumpRouter(
          tester,
          initialLocation: entry.key,
          authState: const AuthState(isLoading: false, isAuthenticated: true),
          petState: _petState(
            isLoading: false,
            hasOnboarded: true,
            pets: [pet],
            activePetId: pet.id,
          ),
        );

        expect(find.byKey(entry.value.field), findsWidgets, reason: entry.key);
        await tester.tap(find.byKey(entry.value.field).last);
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.tap(find.byType(AppBackButton));
        await tester.pumpAndSettle();

        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.text(entry.value.fallback), findsOneWidget);
      }
    },
  );

  testWidgets('/records/:type/new opens category record screens', (
    tester,
  ) async {
    final pet = _pet('1');

    for (final entry in {
      '/records/poop/new': '배변 기록',
      '/records/walk/new': '산책 기록',
      '/records/weight/new': '몸무게 기록',
      '/records/vet/new': '병원 기록',
      '/records/medicine/new': '영양/약 기록',
      '/records/water/new': '음수 기록',
      '/records/diary/new': '일기 기록',
      '/records/etc/new': '기타 기록',
    }.entries) {
      await _pumpRouter(
        tester,
        initialLocation: entry.key,
        authState: const AuthState(isLoading: false, isAuthenticated: true),
        petState: _petState(
          isLoading: false,
          hasOnboarded: true,
          pets: [pet],
          activePetId: pet.id,
        ),
      );

      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(RecordCategoryFormScreen), findsOneWidget);
    }
  });

  testWidgets('/records/:recordId and edit routes open record screens', (
    tester,
  ) async {
    final pet = _pet('1');
    final petState = _petState(
      isLoading: false,
      hasOnboarded: true,
      pets: [pet],
      activePetId: pet.id,
      records: const [
        ActivityRecord(
          id: 'meal-1',
          petId: '1',
          typeId: 'meal',
          date: '2026-05-09',
          time: '09:10:32',
          detail: {
            'foodType': 'wet',
            'servedAmount': 30,
            'consumedPercent': 75,
          },
        ),
      ],
    );

    await _pumpRouter(
      tester,
      initialLocation: '/records/meal-1',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: petState,
    );
    expect(find.text('급식 상세'), findsOneWidget);
    expect(find.byKey(const Key('record-detail-edit-button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-inline-header-trailing-slot')),
        matching: find.byKey(const Key('record-detail-edit-button')),
      ),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const Key('record-detail-edit-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-detail-edit-button')));
    await tester.pumpAndSettle();
    expect(find.text('급식 수정'), findsOneWidget);

    await _pumpRouter(
      tester,
      initialLocation: '/records/meal-1/edit',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: petState,
    );
    expect(find.text('급식 수정'), findsOneWidget);
  });

  testWidgets('/routine/new opens routine creation screen', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/routine/new',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    expect(find.byType(RoutineCreateScreen), findsOneWidget);
    expect(find.text('루틴 추가'), findsOneWidget);
  });

  testWidgets('/routine/schedule/new opens schedule creation screen', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/routine/schedule/new',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    expect(find.byType(RoutineScheduleCreateScreen), findsOneWidget);
    expect(find.text('일정 추가'), findsOneWidget);
  });

  testWidgets('/routine/schedule/:id opens schedule detail screen', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/routine/schedule/s1',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
        schedules: [_schedule('s1', pet.id)],
      ),
    );

    expect(find.text('일정 상세'), findsOneWidget);
    expect(find.byKey(const Key('schedule-detail-hero')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-detail-hero')),
        matching: find.byIcon(Icons.content_cut_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-detail-hero')),
        matching: find.text('목욕 예약'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-detail-hero')),
        matching: find.text('미용'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-detail-info-row-date-time')),
        matching: find.text('6월 17일 10:30 - 11:00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-detail-hero')),
        matching: find.byKey(const Key('schedule-detail-info-row-date-time')),
      ),
      findsNothing,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('schedule-detail-info-row-date-time')),
          )
          .dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('schedule-detail-hero'))).dy,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('schedule-detail-info-row-date-time')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const Key('schedule-detail-info-row-place')))
            .dy,
      ),
    );
    expect(find.text('제목'), findsNothing);
    expect(find.text('카테고리'), findsNothing);
    for (final entry in {
      'place': '동네 미용실',
      'reminder': '하루 전',
      'memo': '빗 챙기기',
    }.entries) {
      expect(
        find.descendant(
          of: find.byKey(Key('schedule-detail-info-row-${entry.key}')),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('schedule-detail-edit-button')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('app-inline-header-trailing-slot')),
        matching: find.byKey(const Key('schedule-detail-edit-button')),
      ),
      findsNothing,
    );
  });

  testWidgets('schedule detail handles all-day range and empty fields', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/routine/schedule/s1',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
        schedules: [
          _schedule(
            's1',
            pet.id,
            title: '강아지와 함께하는 아주 긴 주말 케어 일정 확인',
            endDate: '2026-06-19',
            allDay: true,
            place: null,
            memo: null,
          ),
        ],
      ),
    );

    expect(find.byKey(const Key('schedule-detail-hero')), findsOneWidget);
    expect(find.text('강아지와 함께하는 아주 긴 주말 케어 일정 확인'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-detail-info-row-date-time')),
        matching: find.text('6월 17일 - 6월 19일 종일'),
      ),
      findsOneWidget,
    );
    for (final rowKey in const [
      'schedule-detail-info-row-place',
      'schedule-detail-info-row-memo',
    ]) {
      expect(
        find.descendant(of: find.byKey(Key(rowKey)), matching: find.text('-')),
        findsOneWidget,
      );
    }
  });

  testWidgets('routine schedule card detail button opens detail route', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/routine',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
        schedules: [_schedule('s1', pet.id, startDate: _todayIso())],
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('schedule-detail-button-s1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-detail-button-s1')));
    await tester.pumpAndSettle();

    expect(find.text('일정 상세'), findsOneWidget);
    expect(find.byKey(const Key('schedule-detail-hero')), findsOneWidget);
    expect(find.text('목욕 예약'), findsOneWidget);
  });

  testWidgets('/routine/schedule/:id/edit opens prefilled edit screen', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/routine/schedule/s1/edit',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
        schedules: [_schedule('s1', pet.id)],
      ),
    );

    expect(find.byType(RoutineScheduleCreateScreen), findsOneWidget);
    expect(find.text('일정 수정'), findsOneWidget);
    expect(find.widgetWithText(TextField, '목욕 예약'), findsOneWidget);
  });

  testWidgets('schedule detail edit button opens edit route', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/routine/schedule/s1',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
        schedules: [_schedule('s1', pet.id)],
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('schedule-detail-edit-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-detail-edit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(RoutineScheduleCreateScreen), findsOneWidget);
    expect(find.text('일정 수정'), findsOneWidget);
    expect(find.widgetWithText(TextField, '목욕 예약'), findsOneWidget);
  });

  testWidgets('schedule detail hides missing or inactive pet schedule', (
    tester,
  ) async {
    final pet = _pet('1');
    for (final path in ['/routine/schedule/missing', '/routine/schedule/s2']) {
      await _pumpRouter(
        tester,
        initialLocation: path,
        authState: const AuthState(isLoading: false, isAuthenticated: true),
        petState: _petState(
          isLoading: false,
          hasOnboarded: true,
          pets: [pet],
          activePetId: pet.id,
          schedules: [_schedule('s2', 'other-pet')],
        ),
      );

      expect(find.text('일정을 찾을 수 없어요'), findsOneWidget, reason: path);
      await tester.tap(find.text('루틴으로 돌아가기'));
      await tester.pumpAndSettle();
      expect(find.text('케어 캘린더'), findsOneWidget, reason: path);
    }
  });

  testWidgets('home growth menu opens /records/growth', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/home',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('home-growth-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-growth-button')));
    await tester.pumpAndSettle();

    expect(find.byType(GrowthRecordsScreen), findsOneWidget);
  });

  testWidgets('main scaffold uses neutral bottom navigation colors', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/home',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    final bottomNavigationBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bottomNavigationBar.backgroundColor, AppColors.surface);
    expect(bottomNavigationBar.selectedItemColor, AppColors.primary);
    expect(bottomNavigationBar.unselectedItemColor, AppColors.muted);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final decoratedBox = scaffold.bottomNavigationBar! as DecoratedBox;
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color, AppColors.surface);
    expect(decoration.border!.top.color, AppColors.border);
  });

  testWidgets('/community/category/:category opens inside main scaffold', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/community/category/CARE',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
      communityService: _FakeCommunityService(),
    );

    expect(find.byType(CommunityCategoryScreen), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    final bottomNavigationBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bottomNavigationBar.currentIndex, 1);
  });

  testWidgets('/community/category/POPULAR opens category screen', (
    tester,
  ) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/community/category/POPULAR',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
      communityService: _FakeCommunityService(),
    );

    expect(find.byType(CommunityCategoryScreen), findsOneWidget);
    final bottomNavigationBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bottomNavigationBar.currentIndex, 1);
  });

  testWidgets('my subroutes keep bottom navigation and direct URL fallbacks', (
    tester,
  ) async {
    final pet = _pet('1');
    final petState = _petState(
      isLoading: false,
      hasOnboarded: true,
      pets: [pet],
      activePetId: pet.id,
    );

    for (final entry in {
      '/my/settings': MySettingsScreen,
      '/my/pets': MyPetsScreen,
      '/my/profile': MyProfileScreen,
      '/my/notices': MyNoticesScreen,
      '/my/notices/routine': MyNoticeDetailScreen,
      '/my/support': MySupportCenterScreen,
      '/my/support/records': MyFaqCategoryScreen,
      '/my/support/faq/account-email': MyFaqDetailScreen,
      '/my/inquiry': MyInquiryScreen,
    }.entries) {
      await _pumpRouter(
        tester,
        initialLocation: entry.key,
        authState: const AuthState(isLoading: false, isAuthenticated: true),
        petState: petState,
      );
      expect(find.byType(entry.value), findsOneWidget);
      final navigation = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navigation.currentIndex, 2);

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      final expectedFallback = switch (entry.key) {
        '/my/profile' => '설정',
        '/my/notices/routine' => '최근 공지',
        '/my/support/records' => '고객센터',
        '/my/support/faq/account-email' => '고객센터',
        _ => '마이페이지',
      };
      expect(find.text(expectedFallback), findsWidgets);
    }
  });

  testWidgets('logout loading does not expose onboarding before auth', (
    tester,
  ) async {
    final pet = _pet('1');
    final authNotifier = _MutableAuthNotifier(
      const AuthState(isLoading: false, isAuthenticated: true),
    );
    final petNotifier = _MutablePetNotifier(
      _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );
    await _pumpRouter(
      tester,
      initialLocation: '/my/settings',
      authState: authNotifier.state,
      petState: petNotifier.state,
      authNotifier: authNotifier,
      petNotifier: petNotifier,
    );

    authNotifier.replace(
      const AuthState(isLoading: true, isAuthenticated: true),
    );
    petNotifier.replace(_petState(isLoading: false, hasOnboarded: false));
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsNothing);

    authNotifier.replace(
      const AuthState(isLoading: false, isAuthenticated: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
  });
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  String initialLocation = '/',
  required AuthState authState,
  required PetState petState,
  CommunityService? communityService,
  AuthNotifier? authNotifier,
  PetNotifier? petNotifier,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => authNotifier ?? AuthNotifier.test(authState),
        ),
        petProvider.overrideWith(
          (ref) => petNotifier ?? PetNotifier.test(petState),
        ),
        if (communityService != null)
          communityServiceProvider.overrideWithValue(communityService),
        walletExpenseProvider.overrideWith((ref) => _RouterWalletNotifier()),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final router = ref.watch(routerProvider);
          if (router.routeInformationProvider.value.uri.toString() !=
              initialLocation) {
            router.go(initialLocation);
          }
          return MaterialApp.router(routerConfig: router);
        },
      ),
    ),
  );
  await tester.pump();
  if (authState.isLoading || petState.isLoading) {
    return;
  }
  await tester.pumpAndSettle();
}

PetState _petState({
  required bool isLoading,
  required bool hasOnboarded,
  List<Pet> pets = const [],
  String? activePetId,
  List<ActivityRecord> records = const [],
  List<CareSchedule> schedules = const [],
}) => PetState(
  isLoading: isLoading,
  hasOnboarded: hasOnboarded,
  pets: pets,
  activePetId: activePetId,
  records: records,
  routines: const [],
  schedules: schedules,
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const ['meal', 'water'],
);

Pet _pet(String id) => Pet(
  id: id,
  name: 'Pet $id',
  species: 'dog',
  birthDate: '2022-03-15',
  accentColor: '#F4A460',
  bgLight: '#FFF8F0',
);

CareSchedule _schedule(
  String id,
  String petId, {
  String title = '목욕 예약',
  String startDate = '2026-06-17',
  String? startTime = '10:30',
  String? endDate,
  String? endTime = '11:00',
  bool allDay = false,
  String? place = '동네 미용실',
  String? memo = '빗 챙기기',
  String reminder = '하루 전',
}) => CareSchedule(
  id: id,
  petId: petId,
  categoryId: 'grooming',
  title: title,
  startDate: startDate,
  startTime: startTime,
  endDate: endDate ?? startDate,
  endTime: endTime,
  allDay: allDay,
  place: place,
  memo: memo,
  reminder: reminder,
  createdAt: '2026-06-01T00:00:00.000',
);

String _todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _FakeCommunityService extends CommunityService {
  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
  }) async => const PostFeed(items: [], nextCursor: null);
}

class _RouterWalletNotifier extends WalletExpenseNotifier {
  _RouterWalletNotifier() : super(_FakeWalletExpenseService()) {
    state = WalletExpenseState(
      isLoading: false,
      isMutating: false,
      items: [_walletExpense()],
      summary: const WalletExpenseSummary(
        totalAmount: 12000,
        count: 1,
        currency: 'KRW',
        categories: [],
      ),
      hasMore: false,
    );
  }

  @override
  Future<void> loadFirstPage(String petId) async {}
}

class _FakeWalletExpenseService extends WalletExpenseService {}

WalletExpense _walletExpense() => const WalletExpense(
  id: 'expense-1',
  petId: '1',
  expenseDate: '2026-05-09',
  expenseTime: '09:10:32',
  amount: 12000,
  currency: 'KRW',
  category: 'snack',
  categoryLabel: '\uAC04\uC2DD',
);

class _MutableAuthNotifier extends AuthNotifier {
  _MutableAuthNotifier(super.initialState) : super.test();

  void replace(AuthState next) => state = next;
}

class _MutablePetNotifier extends PetNotifier {
  _MutablePetNotifier(super.initialState) : super.test();

  void replace(PetState next) => state = next;
}
