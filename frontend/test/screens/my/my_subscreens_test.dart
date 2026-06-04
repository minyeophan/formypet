import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/my/my_pets_screen.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/screens/my/my_settings_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('pets list marks only the active pet as current', (tester) async {
    await _pump(
      tester,
      const MyPetsScreen(),
      pets: [_pet('1'), _pet('2')],
      activePetId: '2',
    );

    expect(find.text('나의 반려동물'), findsOneWidget);
    expect(find.text('현재 선택'), findsOneWidget);
  });

  testWidgets('pets list distinguishes loading and empty state', (
    tester,
  ) async {
    await _pump(tester, const MyPetsScreen(), petLoading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _pump(tester, const MyPetsScreen());
    expect(find.text('등록된 펫이 없어요'), findsOneWidget);
  });

  testWidgets('settings confirms logout once while request is running', (
    tester,
  ) async {
    final service = _FakeAuthService()..logoutCompleter = Completer<void>();
    await _pump(tester, const MySettingsScreen(), authService: service);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(service.logoutCalls, 1);

    service.logoutCompleter!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('profile hydrates fields and previews selected local bytes', (
    tester,
  ) async {
    await _pump(
      tester,
      MyProfileScreen(
        pickImage: () async =>
            XFile.fromData(Uint8List.fromList(_png), name: 'profile.png'),
      ),
    );

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller!.text, '보호자');
    expect(fields[1].controller!.text, 'user@example.com');

    await tester.tap(find.text('사진 선택'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-profile-local-preview')), findsOneWidget);
  });

  testWidgets('profile shows loading and missing profile states', (
    tester,
  ) async {
    await _pump(
      tester,
      const MyProfileScreen(),
      authState: const AuthState(isLoading: true, isAuthenticated: true),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _pump(
      tester,
      const MyProfileScreen(),
      authState: const AuthState(isLoading: false, isAuthenticated: true),
    );
    expect(find.text('프로필 정보를 불러올 수 없어요'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<Pet> pets = const [],
  String? activePetId,
  bool petLoading = false,
  AuthService? authService,
  AuthState authState = const AuthState(
    isLoading: false,
    isAuthenticated: true,
    profile: UserProfile(
      id: 'user-1',
      email: 'user@example.com',
      nickname: '보호자',
    ),
  ),
}) {
  return tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.test(authState, service: authService),
        ),
        petProvider.overrideWith(
          (ref) => PetNotifier.test(
            PetState(
              isLoading: petLoading,
              hasOnboarded: pets.isNotEmpty,
              pets: pets,
              activePetId: activePetId,
              records: const [],
              routines: const [],
              todayRoutineItems: const [],
              routineCompletions: const {},
              quickTypeIds: const [],
            ),
          ),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
}

Pet _pet(String id) => Pet(
  id: id,
  name: 'Pet $id',
  species: 'dog',
  birthDate: '2022-03-15',
  accentColor: '#41B883',
  bgLight: '#E8F7EF',
);

class _FakeAuthService extends AuthService {
  Completer<void>? logoutCompleter;
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
    await logoutCompleter?.future;
  }
}

const _png = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  4,
  0,
  0,
  0,
  181,
  28,
  12,
  2,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  100,
  248,
  15,
  0,
  1,
  5,
  1,
  1,
  39,
  24,
  227,
  102,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
