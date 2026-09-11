import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/notification.dart';
import 'package:frontend/providers/home_popular_posts_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/widgets/authenticated_network_image.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/services/notification_service.dart';
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

  testWidgets('news empty state replaces preparing content', (tester) async {
    final popular = await _popularNotifier(const []);
    await tester.pumpWidget(_app(popular: popular));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('포마펫 소식'),
      250,
      scrollable: _homeScrollable(),
    );
    expect(find.text('아직 등록된 소식이 없어요'), findsOneWidget);
    expect(find.text('준비중'), findsNothing);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'news rows at $width show three titles, dates, fallback and open detail',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final popular = await _popularNotifier(const []);
        final news = List.generate(
          4,
          (i) => _post('n$i', title: '소식 $i 아주 긴 제목이 두 줄을 넘으면 말줄임으로 표시됩니다'),
        );
        await tester.pumpWidget(
          _app(popular: popular, news: news, router: _router()),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('home-news-section')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('home-news-n0')), findsOneWidget);
        expect(find.byKey(const Key('home-news-n2')), findsOneWidget);
        expect(find.byKey(const Key('home-news-n3')), findsNothing);
        expect(find.text('2026.07.01'), findsNWidgets(3));
        expect(
          find.byKey(const Key('home-news-image-fallback-n0')),
          findsOneWidget,
        );
        final title = tester.widget<Text>(find.text(news.first.title!));
        expect(title.maxLines, 2);
        final images = tester.widgetList<AuthenticatedNetworkImage>(
          find.descendant(
            of: find.byKey(const Key('home-news-section')),
            matching: find.byType(AuthenticatedNetworkImage),
          ),
        );
        expect(
          images.every((image) => image.width == 80 && image.height == 80),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('home-news-n0')));
        await tester.tap(find.byKey(const Key('home-news-n0')));
        await tester.pumpAndSettle();
        expect(find.text('post:n0:NEWS'), findsOneWidget);
      },
    );
  }

  testWidgets('news all action opens NEWS category even when empty', (
    tester,
  ) async {
    final popular = await _popularNotifier(const []);
    await tester.pumpWidget(_app(popular: popular, router: _router()));
    await tester.pumpAndSettle();
    final action = find.descendant(
      of: find.byKey(const Key('home-news-section')),
      matching: find.text('모두 보기'),
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('news-category'), findsOneWidget);
  });
  testWidgets(
    'news uses first uploaded image and fallback when loading fails',
    (tester) async {
      final popular = await _popularNotifier(const []);
      await tester.pumpWidget(
        _app(
          popular: popular,
          news: [
            _post(
              'image',
              images: [
                'https://example.test/first.jpg',
                'https://example.test/second.jpg',
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<AuthenticatedNetworkImage>(
        find.descendant(
          of: find.byKey(const Key('home-news-section')),
          matching: find.byType(AuthenticatedNetworkImage),
        ),
      );
      expect(image.url, 'https://example.test/first.jpg');
      expect(image.fit, BoxFit.cover);
      expect(
        find.byKey(const Key('home-news-image-fallback-image')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('news failure retries into an empty state', (tester) async {
    final popular = await _popularNotifier(const []);
    final service = _RetryNewsService();
    await tester.pumpWidget(_app(popular: popular, newsService: service));
    await tester.pumpAndSettle();
    expect(find.text('소식을 불러오지 못했어요'), findsOneWidget);
    final retry = find.byKey(const Key('home-news-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('아직 등록된 소식이 없어요'), findsOneWidget);
    expect(find.text('소식을 불러오지 못했어요'), findsNothing);
  });
  testWidgets('notification button navigates without showing a numeric badge', (
    tester,
  ) async {
    final popular = await _popularNotifier(const []);
    await tester.pumpWidget(
      _app(
        popular: popular,
        notificationService: _FakeNotificationService(
          const NotificationFeed(items: [], hasMore: false, unreadCount: 1),
        ),
        router: _routerWithNotifications(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('home-notification-unread-dot')),
      findsOneWidget,
    );
    expect(find.text('1'), findsNothing);
    await tester.tap(find.byKey(const Key('home-notification-button')));
    await tester.pumpAndSettle();
    expect(find.text('notifications'), findsOneWidget);
  });

  testWidgets(
    'notification button hides unread dot when there are no unread items',
    (tester) async {
      final popular = await _popularNotifier(const []);
      await tester.pumpWidget(
        _app(
          popular: popular,
          notificationService: _FakeNotificationService(
            const NotificationFeed(items: [], hasMore: false, unreadCount: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home-notification-unread-dot')),
        findsNothing,
      );
    },
  );

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
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('인기 제목'));
      await tester.pumpAndSettle();
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
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

Widget _app({
  required HomePopularPostsNotifier popular,
  GoRouter? router,
  NotificationService? notificationService,
  List<Post> news = const [],
  CommunityService? newsService,
}) {
  final scope = ProviderScope(
    overrides: [
      petProvider.overrideWith((ref) => _PetNotifier()),
      communityServiceProvider.overrideWithValue(
        newsService ?? _FakeCommunityService(news),
      ),
      authProvider.overrideWith(
        (_) => AuthNotifier.test(
          const AuthState(isLoading: false, isAuthenticated: true),
        ),
      ),
      homePopularPostsProvider.overrideWith((ref) => popular),
      if (notificationService != null)
        notificationServiceProvider.overrideWithValue(notificationService),
    ],
    child: router == null
        ? const MaterialApp(home: HomeScreen())
        : MaterialApp.router(routerConfig: router),
  );
  return scope;
}

GoRouter _routerWithNotifications() => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/notifications',
      builder: (_, _) => const Scaffold(body: Text('notifications')),
    ),
  ],
);

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
    GoRoute(
      path: '/community/category/NEWS',
      builder: (_, _) => const Scaffold(body: Text('news-category')),
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

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService(this.feed);
  final NotificationFeed feed;

  @override
  Future<NotificationFeed> list({String? cursor, int limit = 20}) async => feed;
}

Post _post(
  String id, {
  String? title = '제목',
  String content = '본문',
  List<String> images = const [],
}) => Post(
  id: id,
  userId: 'user',
  authorNickname: 'author',
  title: title,
  content: content,
  category: 'NEWS',
  likesCount: 12,
  liked: false,
  commentsCount: 3,
  imageUrls: images,
  createdAt: '2026-07-01T00:00:00Z',
);

class _RetryNewsService extends CommunityService {
  int calls = 0;
  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) async {
    if (++calls == 1) throw Exception('offline');
    return const PostFeed(items: []);
  }
}
