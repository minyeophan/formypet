import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/community/mock/community_mock_detail_screen.dart';
import 'package:frontend/screens/community/mock/community_mock_feed_screen.dart';
import 'package:frontend/screens/community/mock/community_mock_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('mock notifier seeds posts and updates only local state', () {
    final notifier = MockCommunityNotifier();

    expect(notifier.state.posts, hasLength(5));
    expect(notifier.state.commentsCountFor('story-1'), 22);
    expect(notifier.state.commentsCountFor('photo-1'), 2);
    expect(notifier.state.commentsCountFor('empty-comments-1'), 0);

    notifier.toggleLike('text-1');
    final likedPost = notifier.state.postById('text-1')!;
    expect(likedPost.liked, isTrue);
    expect(likedPost.likesCount, 1);

    notifier.vote('poll-1', 'poll-option-b');
    expect(
      notifier.state
          .postById('poll-1')!
          .poll!
          .options
          .firstWhere((option) => option.id == 'poll-option-b')
          .votesCount,
      1,
    );
    notifier.vote('poll-1', 'poll-option-a');
    final options = notifier.state.postById('poll-1')!.poll!.options;
    expect(
      options.firstWhere((option) => option.id == 'poll-option-a').votesCount,
      1,
    );
    expect(
      options.firstWhere((option) => option.id == 'poll-option-b').votesCount,
      0,
    );

    notifier.addComment('empty-comments-1', '  새 댓글  ');
    notifier.addComment('empty-comments-1', '   ');
    expect(notifier.state.commentsCountFor('empty-comments-1'), 1);
    expect(
      notifier.state.commentsFor('empty-comments-1').single.authorId,
      'mock-me',
    );
    expect(
      notifier.state.commentsFor('empty-comments-1').single.content,
      '새 댓글',
    );
  });

  testWidgets('feed renders every deterministic seed and opens detail', (
    tester,
  ) async {
    await _pumpMockRouter(tester);

    for (final id in [
      'story-1',
      'photo-1',
      'poll-1',
      'text-1',
      'empty-comments-1',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(Key('mock-post-card-$id')),
        220,
        scrollable: _scrollableFor(const Key('mock-feed-scroll')),
      );
      expect(find.byKey(Key('mock-post-card-$id')), findsOneWidget);
      if (id == 'story-1') {
        expect(find.text('댓글 22'), findsOneWidget);
      }
      if (id == 'photo-1') {
        expect(find.text('댓글 2'), findsOneWidget);
      }
      if (id == 'empty-comments-1') {
        expect(find.text('댓글 0'), findsWidgets);
      }
    }

    await tester.scrollUntilVisible(
      find.byKey(const Key('mock-post-card-photo-1')),
      -220,
      scrollable: _scrollableFor(const Key('mock-feed-scroll')),
    );
    await tester.tap(find.byKey(const Key('mock-post-card-photo-1')));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityMockDetailScreen), findsOneWidget);
    expect(find.byKey(const Key('community-image-0')), findsOneWidget);
    expect(find.byKey(const Key('community-image-1')), findsOneWidget);
  });

  testWidgets('story detail follows article and comments mock layout', (
    tester,
  ) async {
    await _pumpMockRouter(
      tester,
      initialLocation: '/community/mock/posts/story-1',
    );

    expect(find.text('게시글 상세'), findsOneWidget);
    expect(find.text('훈훈익명'), findsNWidgets(2));
    expect(find.text('오랜 친구 정리한 마미 있어? 도와줘'), findsOneWidget);
    expect(find.text('익명마미'), findsOneWidget);
    expect(find.text('한시간 전  조회수 1,093'), findsOneWidget);
    expect(find.text('좋아요 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('댓글 22개'),
      260,
      scrollable: _scrollableFor(const Key('mock-detail-scroll')),
    );
    expect(find.text('댓글 22개'), findsOneWidget);
    expect(find.text('댓글을 입력하세요...'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsWidgets);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('mock-post-more-button')));
    await tester.pumpAndSettle();

    expect(find.text('더보기 메뉴'), findsOneWidget);
    expect(find.text('신고하기'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);
  });

  testWidgets('post owner and own comments expose comment management', (
    tester,
  ) async {
    await _pumpMockRouter(
      tester,
      initialLocation: '/community/mock/posts/story-1',
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('mock-comment-more-comment-story-1-best')),
      260,
      scrollable: _scrollableFor(const Key('mock-detail-scroll')),
    );
    expect(
      find.byKey(const Key('mock-comment-more-comment-story-1-best')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('mock-comment-input')),
      '새 댓글',
    );
    await tester.tap(find.byKey(const Key('mock-comment-submit')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('새 댓글'),
      260,
      scrollable: _scrollableFor(const Key('mock-detail-scroll')),
    );
    expect(find.text('새 댓글'), findsOneWidget);
    expect(find.text('댓글 23개'), findsOneWidget);
    expect(
      find.byKey(const Key('mock-comment-more-comment-story-1-4')),
      findsOneWidget,
    );
  });

  testWidgets('detail renders a single image placeholder when present', (
    tester,
  ) async {
    await _pumpMockRouter(
      tester,
      initialLocation: '/community/mock/posts/empty-comments-1',
    );

    expect(find.byKey(const Key('community-image-0')), findsOneWidget);
    expect(find.byKey(const Key('community-image-1')), findsNothing);
  });

  testWidgets('like action is separate from card navigation', (tester) async {
    await _pumpMockRouter(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('mock-post-like-text-1')),
      220,
      scrollable: _scrollableFor(const Key('mock-feed-scroll')),
    );
    await tester.tap(find.byKey(const Key('mock-post-like-text-1')));
    await tester.pump();

    expect(find.byType(CommunityMockFeedScreen), findsOneWidget);
    expect(find.text('좋아요 1'), findsWidgets);
  });

  testWidgets('poll renders zero percent then supports a vote change', (
    tester,
  ) async {
    await _pumpMockRouter(
      tester,
      initialLocation: '/community/mock/posts/poll-1',
    );

    expect(find.text('0%'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('mock-poll-option-poll-option-b')));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mock-poll-option-poll-option-a')));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('comment submission updates detail and feed counts', (
    tester,
  ) async {
    await _pumpMockRouter(
      tester,
      initialLocation: '/community/mock/posts/empty-comments-1',
    );

    await tester.enterText(find.byKey(const Key('mock-comment-input')), '새 댓글');
    await tester.tap(find.byKey(const Key('mock-comment-submit')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('새 댓글'),
      220,
      scrollable: _scrollableFor(const Key('mock-detail-scroll')),
    );
    expect(find.text('새 댓글'), findsOneWidget);
    expect(find.text('댓글 1개'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMockFeedScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('mock-post-card-empty-comments-1')),
      220,
      scrollable: _scrollableFor(const Key('mock-feed-scroll')),
    );
    expect(find.text('댓글 1'), findsOneWidget);
  });

  testWidgets('blank comments do not change the displayed count', (
    tester,
  ) async {
    await _pumpMockRouter(
      tester,
      initialLocation: '/community/mock/posts/empty-comments-1',
    );

    await tester.enterText(find.byKey(const Key('mock-comment-input')), '   ');
    await tester.tap(find.byKey(const Key('mock-comment-submit')));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('댓글 0개'),
      220,
      scrollable: _scrollableFor(const Key('mock-detail-scroll')),
    );
    expect(find.text('댓글 0개'), findsOneWidget);
  });

  testWidgets('unknown post renders a local fallback', (tester) async {
    await _pumpMockRouter(
      tester,
      initialLocation: '/community/mock/posts/missing-post',
    );

    expect(
      find.byKey(const Key('mock-community-post-not-found')),
      findsOneWidget,
    );
  });

  testWidgets('comment input remains above keyboard insets', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await _pumpMockRouter(
      tester,
      initialLocation: '/community/mock/posts/text-1',
    );

    final inputBottom = tester
        .getBottomLeft(find.byKey(const Key('mock-comment-input')))
        .dy;
    expect(inputBottom, lessThanOrEqualTo(620));
  });
}

Future<void> _pumpMockRouter(
  WidgetTester tester, {
  String initialLocation = '/community/mock',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/community/mock',
        builder: (_, _) => const CommunityMockFeedScreen(),
      ),
      GoRoute(
        path: '/community/mock/posts/:postId',
        builder: (_, state) =>
            CommunityMockDetailScreen(postId: state.pathParameters['postId']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

Finder _scrollableFor(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(Scrollable));
