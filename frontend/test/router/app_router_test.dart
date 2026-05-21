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
import 'package:frontend/screens/onboarding/onboarding_screen.dart';
import 'package:frontend/screens/records/records_screen.dart';
import 'package:frontend/screens/splash/splash_screen.dart';
import 'package:frontend/services/community_service.dart';
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

    await tester.tap(find.text('성장곡선'));
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
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  String initialLocation = '/',
  required AuthState authState,
  required PetState petState,
  CommunityService? communityService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => AuthNotifier.test(authState)),
        petProvider.overrideWith((ref) => PetNotifier.test(petState)),
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

class _FakeCommunityService extends CommunityService {
  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
  }) async => const PostFeed(items: [], nextCursor: null);
}
