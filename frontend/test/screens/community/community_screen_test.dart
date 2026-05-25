import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/screens/community/community_screen.dart';
import 'package:frontend/screens/community/write_screen.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('main community screen shows popular feed, carousel, and FAB', (
    tester,
  ) async {
    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(posts: [_post('popular-1', 'CARE')]),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('community-main-popular-feed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('community-category-carousel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('community-category-tile-CARE')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('community-category-tile-EVENT')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('community-notification-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-search-button')), findsOneWidget);
    _expectHeaderActionSurface(tester, 'community-notification-button');
    _expectHeaderActionSurface(tester, 'community-search-button');

    await tester.tap(find.byKey(const Key('community-notification-button')));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-search-button')));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);

    expect(find.byKey(const Key('community-write-fab')), findsOneWidget);
    expect(find.text('popular-1'), findsOneWidget);
  });

  testWidgets('main category carousel renders two fixed panels', (
    tester,
  ) async {
    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(posts: [_post('popular-1', 'CARE')]),
    );

    await tester.pumpAndSettle();

    final firstPanel = find.byKey(const Key('community-category-panel-0'));
    final secondPanel = find.byKey(const Key('community-category-panel-1'));

    expect(firstPanel, findsOneWidget);
    expect(secondPanel, findsOneWidget);
    expect(find.byKey(const Key('community-category-panel-2')), findsNothing);

    for (final category in [
      'ALL',
      'POPULAR',
      'CARE',
      'FOOD',
      'OUTING',
      'SHOW',
      'QUESTION',
      'FREE',
      'ADOPTION',
      'RESCUE',
    ]) {
      expect(
        find.descendant(
          of: firstPanel,
          matching: find.byKey(Key('community-category-tile-$category')),
        ),
        findsOneWidget,
      );
    }

    expect(
      find.descendant(
        of: firstPanel,
        matching: find.byKey(const Key('community-category-tile-NEWS')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: firstPanel,
        matching: find.byKey(const Key('community-category-tile-EVENT')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: secondPanel,
        matching: find.byKey(const Key('community-category-tile-NEWS')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: secondPanel,
        matching: find.byKey(const Key('community-category-tile-EVENT')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('news and event category tiles keep their category routes', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CommunityScreen(),
        ),
        GoRoute(
          path: '/community/category/:category',
          builder: (context, state) =>
              Text('route-${state.pathParameters['category']}'),
        ),
      ],
    );

    await _pumpRouter(
      tester,
      router,
      service: _FakeCommunityService(posts: [_post('popular-1', 'CARE')]),
    );

    await tester.pumpAndSettle();
    final categoryScroller = find.descendant(
      of: find.byKey(const Key('community-category-carousel')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('community-category-tile-NEWS')),
      240,
      scrollable: categoryScroller,
    );
    await tester.tap(find.byKey(const Key('community-category-tile-NEWS')));
    await tester.pumpAndSettle();

    expect(find.text('route-NEWS'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('community-category-tile-EVENT')),
      240,
      scrollable: categoryScroller,
    );
    await tester.tap(find.byKey(const Key('community-category-tile-EVENT')));
    await tester.pumpAndSettle();

    expect(find.text('route-EVENT'), findsOneWidget);
  });

  testWidgets(
    'category screen shows horizontal tabs and latest category feed',
    (tester) async {
      await _pump(
        tester,
        const CommunityCategoryScreen(initialCategory: 'CARE'),
        service: _FakeCommunityService(posts: [_post('care-1', 'CARE')]),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community-category-tabs')), findsOneWidget);
      expect(find.byKey(const Key('community-tab-ALL')), findsOneWidget);
      expect(find.byKey(const Key('community-tab-POPULAR')), findsOneWidget);
      expect(find.byKey(const Key('community-tab-CARE')), findsOneWidget);
      expect(find.text('care-1'), findsOneWidget);
    },
  );

  testWidgets('category screen header title stays community and left aligned', (
    tester,
  ) async {
    await _pump(
      tester,
      const CommunityCategoryScreen(initialCategory: 'CARE'),
      service: _FakeCommunityService(posts: [_post('care-1', 'CARE')]),
    );

    await tester.pumpAndSettle();

    final titleFinder = find.byKey(const Key('community-header-title'));
    expect(titleFinder, findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);

    final titleLeft = tester.getTopLeft(titleFinder).dx;
    final leadingRight = tester
        .getTopRight(find.byKey(const Key('community-header-leading-slot')))
        .dx;
    expect(titleLeft, greaterThanOrEqualTo(leadingRight));
    expect(titleLeft, lessThan(90));
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('community-guide-panel')),
        matching: find.byType(AppDisclosureChevron),
      ),
      findsOneWidget,
    );
  });

  testWidgets('write screen uses the shared back button', (tester) async {
    await _pump(tester, const WriteScreen(), service: _FakeCommunityService());

    expect(find.byType(AppBackButton), findsOneWidget);
  });

  testWidgets(
    'write screen shows thumbnail rail, emoji buttons, and poll panel',
    (tester) async {
      await _pump(
        tester,
        const WriteScreen(),
        service: _FakeCommunityService(),
      );

      expect(
        find.byKey(const Key('community-attachment-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-add-image-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community-add-poll-button')),
        findsOneWidget,
      );
      expect(find.text('🖼'), findsOneWidget);
      expect(find.text('📊'), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-add-poll-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community-poll-panel')), findsOneWidget);
    },
  );
}

void _expectHeaderActionSurface(WidgetTester tester, String key) {
  final finder = find.byKey(Key(key));
  expect(tester.getSize(finder), const Size(38, 38));

  final container = tester.widget<Container>(
    find.descendant(of: finder, matching: find.byType(Container)).first,
  );
  final decoration = container.decoration as BoxDecoration;
  expect(decoration.color, AppColors.surface);
  expect(decoration.borderRadius, BorderRadius.circular(14));
  expect(decoration.border, Border.all(color: AppColors.border));

  final icon = tester.widget<Icon>(
    find.descendant(of: finder, matching: find.byType(Icon)).first,
  );
  expect(icon.size, 20);
  expect(icon.color, AppColors.textSecondary);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required CommunityService service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityServiceProvider.overrideWithValue(service)],
      child: MaterialApp(home: child),
    ),
  );
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  required CommunityService service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

Post _post(String content, String category) => Post(
  id: content,
  userId: 'user-1',
  authorNickname: 'Momo',
  content: content,
  category: category,
  likesCount: 0,
  liked: false,
  commentsCount: 0,
  imageUrls: const [],
  createdAt: '2026-05-21T12:00:00',
);

class _FakeCommunityService extends CommunityService {
  _FakeCommunityService({this.posts = const []});

  final List<Post> posts;

  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
  }) async => PostFeed(items: posts, nextCursor: null);
}
