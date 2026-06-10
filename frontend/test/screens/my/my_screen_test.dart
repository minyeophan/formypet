import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/my/my_policies_screen.dart';
import 'package:frontend/screens/onboarding/onboarding_screen.dart';
import 'package:frontend/screens/my/my_pets_screen.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/screens/my/my_settings_screen.dart';
import 'package:frontend/screens/pet/pet_detail_screen.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders my page mockup content without account exit actions', (
    tester,
  ) async {
    await _pumpMyScreen(tester);

    expect(find.text('마이페이지'), findsOneWidget);
    expect(find.text('마이펫'), findsOneWidget);
    expect(find.text('초코'), findsOneWidget);
    expect(find.text('펫 추가하기'), findsOneWidget);

    for (final text in [
      '정보',
      '내 프로필 편집',
      '공동집사 관리',
      '나의 활동',
      '내가 쓴 글',
      '내가 공감한 글',
      '내가 댓글 남긴 글',
      '설정',
      '일반 설정',
      '알림 설정',
      '고객지원',
      '공지사항',
      '고객센터',
      '1대1 문의하기',
      '약관 및 정책',
      '앱 버전 v2.04',
    ]) {
      await _expectTextVisible(tester, text);
    }

    expect(find.text('로그아웃'), findsNothing);
    expect(find.text('회원탈퇴'), findsNothing);
    expect(find.byType(AppDisclosureChevron), findsWidgets);
  });

  testWidgets('pet card opens pet detail route', (tester) async {
    await _pumpMyScreen(tester);

    await tester.tap(find.byKey(const Key('my-pet-card-1')));
    await tester.pumpAndSettle();

    expect(find.byType(PetDetailScreen), findsOneWidget);
    expect(find.text('생년월일'), findsOneWidget);
  });

  testWidgets('add pet card opens additional pet route', (tester) async {
    await _pumpMyScreen(tester);

    await tester.tap(find.byKey(const Key('my-add-pet-card')));
    await tester.pumpAndSettle();

    final screen = tester.widget<OnboardingScreen>(
      find.byType(OnboardingScreen),
    );
    expect(screen.mode, PetEntryMode.additionalPet);
  });

  testWidgets('unsupported menu controls show preparing snack bar', (
    tester,
  ) async {
    await _pumpMyScreen(tester);

    await _tapMenuRow(tester, '공동집사 관리');
    expect(find.text('준비중'), findsOneWidget);
  });

  testWidgets('policy menu opens policy list route', (tester) async {
    await _pumpMyScreen(tester);

    await _tapMenuRow(tester, '약관 및 정책');
    await tester.pumpAndSettle();

    expect(find.byType(MyPoliciesScreen), findsOneWidget);
    expect(find.text('서비스 이용약관'), findsOneWidget);
  });

  testWidgets('settings button uses the shared 38px icon surface', (
    tester,
  ) async {
    await _pumpMyScreen(tester);

    final finder = find.byKey(const Key('my-settings-button'));
    expect(tester.getSize(finder), const Size(38, 38));

    final container = tester.widget<Container>(
      find.descendant(of: finder, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(14));
    expect(decoration.border, Border.all(color: AppColors.border));

    final icon = tester.widget<Icon>(
      find.descendant(of: finder, matching: find.byType(Icon)).first,
    );
    expect(icon.size, 20);
    expect(icon.color, AppColors.textSecondary);
  });

  testWidgets('settings, all pets, and profile controls open real routes', (
    tester,
  ) async {
    await _pumpMyScreen(tester);
    await tester.tap(find.byKey(const Key('my-settings-button')));
    await tester.pumpAndSettle();
    expect(find.byType(MySettingsScreen), findsOneWidget);

    await _pumpMyScreen(tester);
    await tester.tap(find.byKey(const Key('my-view-all-pets')));
    await tester.pumpAndSettle();
    expect(find.byType(MyPetsScreen), findsOneWidget);

    await _pumpMyScreen(tester);
    await _tapMenuRow(tester, '내 프로필 편집');
    await tester.pumpAndSettle();
    expect(find.byType(MyProfileScreen), findsOneWidget);
  });

  testWidgets('main pet card prefers active pet and shows loading spinner', (
    tester,
  ) async {
    await _pumpMyScreen(tester, pets: [_pet('1'), _pet('2')], activePetId: '2');
    expect(find.byKey(const Key('my-pet-card-2')), findsOneWidget);

    await _pumpMyScreen(tester, isLoading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

Future<void> _pumpMyScreen(
  WidgetTester tester, {
  List<Pet>? pets,
  String? activePetId,
  bool isLoading = false,
}) async {
  final resolvedPets = pets ?? [_pet('1')];
  final resolvedActivePetId = activePetId ?? resolvedPets.first.id;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.test(
            const AuthState(
              isLoading: false,
              isAuthenticated: true,
              profile: UserProfile(
                id: 'user-1',
                email: 'user@example.com',
                nickname: '보호자',
              ),
            ),
          ),
        ),
        petProvider.overrideWith(
          (ref) => PetNotifier.test(
            _petState(
              pets: resolvedPets,
              activePetId: resolvedActivePetId,
              isLoading: isLoading,
            ),
          ),
        ),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final router = ref.watch(routerProvider);
          if (router.routeInformationProvider.value.uri.toString() != '/my') {
            router.go('/my');
          }
          return MaterialApp.router(routerConfig: router);
        },
      ),
    ),
  );
  if (isLoading) {
    await tester.pump();
    return;
  }
  await tester.pumpAndSettle();
}

Future<void> _expectTextVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder, findsOneWidget);
}

Future<void> _tapMenuRow(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

PetState _petState({
  required List<Pet> pets,
  required String activePetId,
  bool isLoading = false,
}) => PetState(
  isLoading: isLoading,
  hasOnboarded: true,
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
  name: id == '1' ? '초코' : '보리',
  species: '푸들',
  birthDate: '2022-03-15',
  accentColor: '#41B883',
  bgLight: '#E8F7EF',
  weight: 4.2,
  neutered: true,
);
