import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/screens/community/community_screen.dart';
import 'package:frontend/screens/community/write_screen.dart';
import 'package:frontend/services/community_service.dart';
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
    expect(find.byKey(const Key('community-write-fab')), findsOneWidget);
    expect(find.text('popular-1'), findsOneWidget);
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
