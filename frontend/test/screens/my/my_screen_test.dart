import 'package:frontend/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/my_community_activity.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/screens/my/my_activity_screen.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/models/notification.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/my/my_inquiry_screen.dart';
import 'dart:async';
import 'package:frontend/services/inquiry_service.dart';
import 'package:frontend/screens/my/my_notices_screen.dart';
import 'package:frontend/screens/my/my_policies_screen.dart';
import 'package:frontend/screens/my/my_support_center_screen.dart';
import 'package:frontend/screens/my/my_pets_screen.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/screens/my/my_settings_screen.dart';
import 'package:frontend/screens/my/my_blocked_users_screen.dart';
import 'package:frontend/providers/blocked_users_provider.dart';
import 'package:frontend/screens/notification/notification_screen.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'inquiry opens above tab navigation and protects pending submission',
    (tester) async {
      final service = _PendingInquiryService();
      await _pumpMyScreen(tester, inquiryService: service);
      await _tapMenuRow(tester, '1대1 문의하기');
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar).hitTestable(), findsNothing);
      await tester.enterText(find.byKey(const Key('inquiry-title')), '문의 제목');
      await tester.enterText(
        find.byKey(const Key('my-inquiry-body-field')),
        '문의 내용',
      );
      await tester.tap(find.byKey(const Key('inquiry-submit')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MyInquiryScreen), findsOneWidget);
      expect(service.calls, 1);
      service.pending.complete(
        InquiryReceipt(id: 'i1', receivedAt: DateTime(2026)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inquiry-done')));
      await tester.pumpAndSettle();
      expect(find.byType(MyInquiryScreen), findsNothing);
      expect(find.byType(BottomNavigationBar).hitTestable(), findsOneWidget);
    },
  );
  for (final entry in {
    '내가 쓴 글': '아직 작성한 글이 없어요.',
    '내가 공감한 글': '아직 공감한 글이 없어요.',
    '내가 댓글 남긴 글': '아직 댓글을 남긴 글이 없어요.',
  }.entries) {
    testWidgets('${entry.key} opens its real activity tab', (tester) async {
      await _pumpMyScreen(tester);
      await _tapMenuRow(tester, entry.key);
      await tester.pumpAndSettle();
      expect(find.byType(MyActivityScreen), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
    });
  }
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders my page mockup content without account exit actions', (
    tester,
  ) async {
    await _pumpMyScreen(tester);

    expect(find.text('마이페이지'), findsOneWidget);
    expect(find.text('마이펫'), findsNothing);
    expect(find.text('펫 추가하기'), findsNothing);

    for (final text in [
      '정보',
      '내 프로필 편집',
      '반려동물 관리',
      '공동집사 관리',
      '나의 활동',
      '내가 쓴 글',
      '내가 공감한 글',
      '내가 댓글 남긴 글',
      '설정',
      '일반 설정',
      '차단 목록',
      '알림 내역',
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

  testWidgets('pet management menu opens the pet list route', (tester) async {
    await _pumpMyScreen(tester);

    await _tapMenuRow(tester, '반려동물 관리');
    await tester.pumpAndSettle();

    expect(find.byType(MyPetsScreen), findsOneWidget);
  });

  testWidgets('general settings menu opens the existing settings screen', (
    tester,
  ) async {
    await _pumpMyScreen(tester);

    await _tapMenuRow(tester, '일반 설정');
    await tester.pumpAndSettle();

    expect(find.byType(MySettingsScreen), findsOneWidget);
  });

  for (final fromSettings in [false, true]) {
    testWidgets('${fromSettings ? 'settings' : 'main'} opens blocked list', (
      tester,
    ) async {
      await _pumpMyScreen(tester);
      if (fromSettings) {
        await tester.tap(find.byKey(const Key('my-settings-button')));
        await tester.pumpAndSettle();
      }
      await _tapMenuRow(tester, '차단 목록');
      await tester.pumpAndSettle();
      expect(find.byType(MyBlockedUsersScreen), findsOneWidget);
      expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
    });
    testWidgets(
      '${fromSettings ? 'settings' : 'main'} notification history opens the inbox',
      (tester) async {
        await _pumpMyScreen(tester);
        if (fromSettings) {
          await tester.tap(find.byKey(const Key('my-settings-button')));
          await tester.pumpAndSettle();
        }

        expect(find.text('알림 내역'), findsOneWidget);
        await _tapMenuRow(tester, '알림 내역');
        await tester.pumpAndSettle();

        expect(find.byType(NotificationScreen), findsOneWidget);
        expect(find.text('새로운 알림이 없어요.'), findsOneWidget);
      },
    );
  }

  for (final label in ['공동집사 관리']) {
    testWidgets('$label is visibly preparing and disabled', (tester) async {
      await _pumpMyScreen(tester);
      await _expectTextVisible(tester, label);
      final row = find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first;

      expect(
        find.descendant(of: row, matching: find.text('준비중')),
        findsOneWidget,
      );
      expect(tester.widget<InkWell>(row).onTap, isNull);
      expect(
        find.descendant(of: row, matching: find.byType(AppDisclosureChevron)),
        findsNothing,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('마이페이지'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  }

  testWidgets('policy menu opens policy list route', (tester) async {
    await _pumpMyScreen(tester);

    await _tapMenuRow(tester, '약관 및 정책');
    await tester.pumpAndSettle();

    expect(find.byType(MyPoliciesScreen), findsOneWidget);
    expect(find.text('서비스 이용약관'), findsOneWidget);
  });

  testWidgets('support menu rows open real routes', (tester) async {
    await _pumpMyScreen(tester);
    await _tapMenuRow(tester, '공지사항');
    await tester.pumpAndSettle();
    expect(find.byType(MyNoticesScreen), findsOneWidget);

    await _pumpMyScreen(tester);
    await _tapMenuRow(tester, '고객센터');
    await tester.pumpAndSettle();
    expect(find.byType(MySupportCenterScreen), findsOneWidget);

    await _pumpMyScreen(tester);
    await _tapMenuRow(tester, '1대1 문의하기');
    await tester.pumpAndSettle();
    expect(find.byType(MyInquiryScreen), findsOneWidget);
  });

  testWidgets('settings button uses the shared 44px touch target', (
    tester,
  ) async {
    await _pumpMyScreen(tester);

    final finder = find.byKey(const Key('my-settings-button'));
    expect(tester.getSize(finder), const Size(44, 44));

    final container = tester.widget<Ink>(
      find.descendant(of: finder, matching: find.byType(Ink)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(14));
    expect(decoration.border, Border.all(color: AppColors.border));

    final icon = tester.widget<AppIcon>(
      find.descendant(of: finder, matching: find.byType(AppIcon)).first,
    );
    expect(icon.size, 20);
    expect(icon.color, AppColors.textSecondary);
  });

  testWidgets('settings and profile controls open real routes', (tester) async {
    await _pumpMyScreen(tester);
    await tester.tap(find.byKey(const Key('my-settings-button')));
    await tester.pumpAndSettle();
    expect(find.byType(MySettingsScreen), findsOneWidget);

    await _pumpMyScreen(tester);
    await _tapMenuRow(tester, '내 프로필 편집');
    await tester.pumpAndSettle();
    expect(find.byType(MyProfileScreen), findsOneWidget);
  });
}

Future<void> _pumpMyScreen(
  WidgetTester tester, {
  InquiryService? inquiryService,
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
        if (inquiryService != null)
          inquiryServiceProvider.overrideWithValue(inquiryService),
        blockedUsersProvider.overrideWith((_) async => []),
        communityServiceProvider.overrideWithValue(_EmptyActivityService()),
        notificationServiceProvider.overrideWithValue(
          _EmptyNotificationService(),
        ),
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

class _EmptyActivityService extends CommunityService {
  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) async => const PostFeed(items: []);
  @override
  Future<MyActivityPage> getMyActivities(
    MyActivityType type, {
    String? cursor,
  }) async => const MyActivityPage([], null);
}

Future<void> _expectTextVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsOneWidget);
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

class _EmptyNotificationService extends NotificationService {
  @override
  Future<NotificationFeed> list({String? cursor, int limit = 20}) async =>
      NotificationFeed(items: [], hasMore: false, unreadCount: 0);
}

class _PendingInquiryService extends InquiryService {
  final pending = Completer<InquiryReceipt>();
  int calls = 0;
  @override
  Future<InquiryReceipt> submit(
    InquiryDraft draft, {
    required String requestId,
  }) {
    calls++;
    return pending.future;
  }
}
