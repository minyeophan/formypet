import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/auth/auth_screen.dart';
import 'package:frontend/screens/community/community_screen.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/screens/my/my_pets_screen.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/screens/my/my_settings_screen.dart';
import 'package:frontend/screens/onboarding/onboarding_screen.dart';
import 'package:frontend/screens/records/expense_add_screen.dart';
import 'package:frontend/screens/records/record_category_form_screen.dart';
import 'package:frontend/screens/records/records_screen.dart';
import 'package:frontend/screens/routine/routine_create_screen.dart';
import 'package:frontend/screens/routine/routine_schedule_create_screen.dart';
import 'package:frontend/screens/splash/splash_screen.dart';
import 'package:frontend/services/community_service.dart';
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

  testWidgets('/records/expense/new opens expense add screen', (tester) async {
    final pet = _pet('1');
    await _pumpRouter(
      tester,
      initialLocation: '/records/expense/new',
      authState: const AuthState(isLoading: false, isAuthenticated: true),
      petState: _petState(
        isLoading: false,
        hasOnboarded: true,
        pets: [pet],
        activePetId: pet.id,
      ),
    );

    expect(find.byType(ExpenseAddScreen), findsOneWidget);
    expect(find.text('비용 추가'), findsOneWidget);
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

    expect(find.text('집사의 지갑'), findsOneWidget);
    expect(find.text('비용 추가'), findsOneWidget);
    expect(find.text('내역 보기'), findsOneWidget);
    expect(find.text('약 연동'), findsNothing);
    expect(find.text('빠른 지출'), findsNothing);
    expect(find.text('빠르게 저장'), findsNothing);
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

    expect(find.text('지출 리포트'), findsOneWidget);
    expect(find.text('약 연동'), findsNothing);
    expect(find.text('빠른 지출'), findsNothing);
    expect(find.text('빠르게 저장'), findsNothing);
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

    await tester.tap(find.text('지갑'));
    await tester.pumpAndSettle();

    expect(find.text('집사의 지갑'), findsOneWidget);
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

    await tester.tap(find.text('비용 추가'));
    await tester.pumpAndSettle();
    expect(find.text('비용 추가'), findsOneWidget);
    expect(find.text('금액'), findsOneWidget);

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

    await tester.tap(find.text('내역 보기'));
    await tester.pumpAndSettle();
    expect(find.text('지출 리포트'), findsOneWidget);
  });

  testWidgets('direct URL back buttons use their screen fallback routes', (
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
      '/routine': '홈',
      '/records': '홈',
      '/records/all': 'Pet 1의 반려기록',
      '/records/growth': '홈',
      '/wallet': '홈',
      '/wallet/report': '집사의 지갑',
      '/records/meal/new': 'Pet 1의 반려기록',
      '/records/walk/new': 'Pet 1의 반려기록',
      '/records/expense/new': '집사의 지갑',
    }.entries) {
      await _pumpRouter(
        tester,
        initialLocation: entry.key,
        authState: const AuthState(isLoading: false, isAuthenticated: true),
        petState: petState,
      );

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsWidgets, reason: entry.key);
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
        '/records/expense/new': (
          field: const Key('expense-item-name-field'),
          fallback: '집사의 지갑',
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

        await tester.tap(find.byTooltip('뒤로가기'));
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

    await tester.ensureVisible(find.text('성장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('성장'));
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
      expect(
        find.text(entry.key == '/my/profile' ? '설정' : '마이페이지'),
        findsWidgets,
      );
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
}) => PetState(
  isLoading: isLoading,
  hasOnboarded: hasOnboarded,
  pets: pets,
  activePetId: activePetId,
  records: const [],
  routines: const [],
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

class _MutableAuthNotifier extends AuthNotifier {
  _MutableAuthNotifier(super.initialState) : super.test();

  void replace(AuthState next) => state = next;
}

class _MutablePetNotifier extends PetNotifier {
  _MutablePetNotifier(super.initialState) : super.test();

  void replace(PetState next) => state = next;
}
