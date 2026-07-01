import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/home_popular_posts_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/services/community_service.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('renders Home V2 sections in order without legacy sections', (
    tester,
  ) async {
    final popular = await _popularNotifier([_post('1')]);
    await tester.pumpWidget(_app(popular: popular));
    await tester.pump();

    expect(find.text('ForMyPet'), findsOneWidget);
    expect(find.byKey(const Key('home-v2-header')), findsOneWidget);
    expect(find.byKey(const Key('home-profile-card-1')), findsOneWidget);
    expect(find.byKey(const Key('home-menu-panel')), findsOneWidget);
    expect(find.byKey(const Key('home-news-section')), findsOneWidget);
    expect(find.text('오늘 관리'), findsNothing);
    expect(find.text('오늘 타임라인'), findsNothing);
    expect(find.text('최근 건강 상태'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-popular-section')),
      300,
      scrollable: _homeScrollable(),
    );
    expect(find.byKey(const Key('home-popular-section')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-bottom-banner')),
      300,
      scrollable: _homeScrollable(),
    );
    expect(find.text('오늘 하루도 포마이펫과 함께!'), findsOneWidget);
  });

  testWidgets('news cards are local preparing content', (tester) async {
    final popular = await _popularNotifier(const []);
    await tester.pumpWidget(_app(popular: popular));
    await tester.scrollUntilVisible(
      find.text('오늘의 뉴스'),
      250,
      scrollable: _homeScrollable(),
    );

    expect(find.text('준비중'), findsNWidgets(3));
    expect(find.textContaining('간식'), findsOneWidget);
    expect(find.textContaining('산책'), findsOneWidget);
    expect(find.textContaining('치아관리'), findsOneWidget);
    await tester.tap(find.text('모두 보기'));
    await tester.pump();
    expect(find.text('준비중'), findsWidgets);
  });

  testWidgets(
    'popular posts use title fallbacks and navigate to popular source',
    (tester) async {
      final popular = await _popularNotifier([
        _post('1', title: '인기 제목'),
        _post('2', title: ' ', content: '본문 제목'),
        _post('3', title: null, content: ''),
      ]);
      final router = _router();
      await tester.pumpWidget(_app(popular: popular, router: router));
      await tester.scrollUntilVisible(
        find.text('인기 제목'),
        300,
        scrollable: _homeScrollable(),
      );

      expect(find.text('본문 제목'), findsOneWidget);
      expect(find.text('내용 없음'), findsOneWidget);
      await tester.tap(find.text('인기 제목'));
      await tester.pumpAndSettle();
      expect(find.text('post:1:popular'), findsOneWidget);
    },
  );

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('does not overflow at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final popular = await _popularNotifier([
        _post('1', title: '아주 긴 인기글 제목이 화면 밖으로 넘치지 않아야 합니다'),
      ]);
      await tester.pumpWidget(_app(popular: popular));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

Finder _homeScrollable() => find.byWidgetPredicate(
  (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

Widget _app({required HomePopularPostsNotifier popular, GoRouter? router}) {
  final scope = ProviderScope(
    overrides: [
      petProvider.overrideWith((ref) => _PetNotifier()),
      homePopularPostsProvider.overrideWith((ref) => popular),
    ],
    child: router == null
        ? const MaterialApp(home: HomeScreen())
        : MaterialApp.router(routerConfig: router),
  );
  return scope;
}

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/community/posts/:id',
      builder: (_, state) => Scaffold(
        body: Text(
          'post:${state.pathParameters['id']}:${state.uri.queryParameters['source']}',
        ),
      ),
    ),
    for (final path in ['/records', '/wallet', '/routine', '/records/growth'])
      GoRoute(path: path, builder: (_, _) => const SizedBox()),
  ],
);

Future<HomePopularPostsNotifier> _popularNotifier(List<Post> posts) async {
  final notifier = HomePopularPostsNotifier(_FakeCommunityService(posts));
  await notifier.load();
  return notifier;
}

class _PetNotifier extends PetNotifier {
  _PetNotifier()
    : super.test(
        PetState(
          isLoading: false,
          hasOnboarded: true,
          pets: const [
            Pet(
              id: '1',
              name: '이름이 아주 긴 몽실이',
              species: 'dog',
              birthDate: '2022-03-15',
              breed: '푸들',
              adoptionDate: '2023-04-01',
              accentColor: '#F4A460',
              bgLight: '#FFF8F0',
            ),
          ],
          activePetId: '1',
          records: const [],
          routines: const [],
          todayRoutineItems: const [],
          routineCompletions: const {},
          quickTypeIds: const [],
        ),
      );

  @override
  Future<void> setActivePet(String petId) async {}

  @override
  Future<void> refreshPets() async {}
}

class _FakeCommunityService extends CommunityService {
  _FakeCommunityService(this.posts);
  final List<Post> posts;

  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) async => PostFeed(items: posts);
}

Post _post(String id, {String? title = '제목', String content = '본문'}) => Post(
  id: id,
  userId: 'user',
  authorNickname: 'author',
  title: title,
  content: content,
  category: 'FREE',
  likesCount: 12,
  liked: false,
  commentsCount: 3,
  imageUrls: const [],
  createdAt: '2026-07-01T00:00:00Z',
);
