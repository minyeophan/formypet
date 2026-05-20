import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/auth/auth_screen.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/screens/onboarding/onboarding_screen.dart';
import 'package:frontend/screens/splash/splash_screen.dart';
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
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  String initialLocation = '/',
  required AuthState authState,
  required PetState petState,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => AuthNotifier.test(authState)),
        petProvider.overrideWith((ref) => PetNotifier.test(petState)),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final router = ref.watch(routerProvider);
          if (router.routeInformationProvider.value.uri.path !=
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
