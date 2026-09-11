import 'package:frontend/screens/community/community_comments_screen.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:frontend/widgets/app_ink_well.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/app_v2_tokens.dart';
import 'package:frontend/core/visuals/app_visual_id.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/screens/community/community_detail_screen.dart';
import 'package:frontend/services/community_service.dart';

import '../../support/app_visual_finder.dart';
import 'package:frontend/widgets/authenticated_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('reply management routes the selected reply and its root', (
    tester,
  ) async {
    Uri? openedUri;
    final router = GoRouter(
      initialLocation: '/community/posts/post-1',
      routes: [
        GoRoute(
          path: '/community/posts/:postId',
          builder: (_, _) => const CommunityDetailScreen(postId: 'post-1'),
        ),
        GoRoute(
          path: '/community/posts/:postId/comments',
          builder: (_, state) {
            openedUri = state.uri;
            return Scaffold(body: Text(state.uri.toString()));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpDetail(
      tester,
      router: router,
      currentUserId: 'me',
      comments: [
        _comment(
          id: 'root',
          userId: 'other',
          replyCount: 1,
          replies: [
            _comment(id: 'reply', userId: 'me', parentCommentId: 'root'),
          ],
        ),
      ],
    );
    final button = find.byKey(const Key('community-comment-more-reply'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(openedUri?.queryParameters, containsPair('thread', 'root'));
    expect(openedUri?.queryParameters, containsPair('targetComment', 'reply'));
    expect(openedUri?.queryParameters, containsPair('manage', 'true'));
    expect(find.text('준비중'), findsNothing);
  });

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    initApiClient('http://example.test', includeAuthInterceptor: false);
  });

  setUp(() {
    dio.httpClientAdapter = _CannedAdapter((options) {
      return ResponseBody.fromBytes(
        Uint8List.fromList([1, 2, 3]),
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
        },
      );
    });
  });

  testWidgets('shows post more button after loading detail', (tester) async {
    await _pumpDetail(tester);

    expect(find.byKey(const Key('community-detail-back')), findsOneWidget);
    expect(
      find.byKey(const Key('community-detail-more-button')),
      findsOneWidget,
    );
  });

  testWidgets('uses the V2 header and comment launcher', (tester) async {
    await _pumpDetail(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppV2Tokens.background);
    expect(
      find.byKey(const Key('community-detail-comment-launcher')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-detail-top-button')), findsNothing);
    expect(find.text('소중한 댓글을 남겨주세요'), findsOneWidget);
  });

  testWidgets('comment launcher shows a two pixel outline on keyboard focus', (
    tester,
  ) async {
    await _pumpDetail(tester);

    await _expectKeyboardRing(
      tester,
      const Key('community-detail-comment-launcher'),
    );
  });

  testWidgets('like statistic shows a keyboard ring without shifting', (
    tester,
  ) async {
    await _pumpDetail(tester);
    await _expectKeyboardRing(tester, const Key('community-detail-like'));
  });

  testWidgets('reply link shows a keyboard ring without shifting', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      comments: [_comment(id: 'one', userId: 'user-1')],
    );
    await _expectKeyboardRing(tester, const Key('community-comment-reply-one'));
  });

  testWidgets('requests a three-root two-reply preview', (tester) async {
    final service = _FakeCommunityService(
      post: _post(userId: 'user-1'),
      comments: const [],
    );
    await _pumpDetail(tester, service: service);

    expect(service.lastCommentsLimit, 3);
    expect(service.lastReplyLimit, 2);
  });

  testWidgets(
    'renders empty title and author fallbacks while preserving body',
    (tester) async {
      await _pumpDetail(
        tester,
        post: Post(
          id: 'post-1',
          userId: 'user-1',
          authorNickname: '',
          title: ' ',
          content: '본문은 항상 표시',
          category: 'FREE',
          likesCount: 0,
          liked: false,
          commentsCount: 0,
          imageUrls: const [],
          createdAt: '2026-06-24T00:00:00',
        ),
      );

      expect(find.text('익명집사'), findsOneWidget);
      expect(find.text('제목 없음'), findsOneWidget);
      expect(find.text('본문은 항상 표시'), findsOneWidget);
    },
  );

  testWidgets('opens post more menu', (tester) async {
    await _pumpDetail(tester);

    await tester.tap(find.byKey(const Key('community-detail-more-button')));
    await tester.pumpAndSettle();

    expect(find.text('더보기 메뉴'), findsOneWidget);
    expect(find.text('신고하기'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);
  });

  testWidgets('report action shows preparing toast', (tester) async {
    await _pumpDetail(tester);

    await tester.tap(find.byKey(const Key('community-detail-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고하기'));
    await tester.pump();

    expect(find.text('준비중'), findsOneWidget);
  });

  testWidgets('comment author can see comment management', (tester) async {
    await _pumpDetail(
      tester,
      currentUserId: 'comment-owner',
      comments: [_comment(id: 'own', userId: 'comment-owner')],
    );

    expect(find.byKey(const Key('community-comment-more-own')), findsOneWidget);
  });

  testWidgets('post author can manage another user comment', (tester) async {
    await _pumpDetail(
      tester,
      currentUserId: 'post-owner',
      post: _post(userId: 'post-owner'),
      comments: [_comment(id: 'other', userId: 'comment-owner')],
    );

    expect(
      find.byKey(const Key('community-comment-more-other')),
      findsOneWidget,
    );
  });

  testWidgets('user without permission cannot see comment management', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      currentUserId: 'viewer',
      post: _post(userId: 'post-owner'),
      comments: [_comment(id: 'other', userId: 'comment-owner')],
    );

    expect(find.byKey(const Key('community-comment-more-other')), findsNothing);
  });

  testWidgets('does not render a separate comment section title', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      comments: [_comment(id: 'one', userId: 'user-1')],
    );

    expect(find.text('댓글 1'), findsNothing);
  });

  testWidgets('shows top divider on comment launcher', (tester) async {
    await _pumpDetail(
      tester,
      comments: [_comment(id: 'one', userId: 'user-1')],
    );

    final launcher = tester.widget<Container>(
      find.byKey(const Key('community-detail-launcher-shell')),
    );
    final decoration = launcher.decoration as BoxDecoration;
    expect(decoration.border!.top.color, AppV2Tokens.border);
  });

  testWidgets('renders comments as flat rows', (tester) async {
    await _pumpDetail(
      tester,
      comments: [_comment(id: 'one', userId: 'user-1')],
    );

    expect(find.byKey(const Key('community-root-one')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('community-root-one')),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
  });

  testWidgets('renders authenticated network image for comment avatar url', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      comments: [
        _comment(
          id: 'one',
          userId: 'user-1',
          authorProfileImageUrl: '/api/v1/users/1/profile-image',
        ),
      ],
    );

    final image = tester.widget<AuthenticatedNetworkImage>(
      find.byType(AuthenticatedNetworkImage).first,
    );
    expect(image.url, '/api/v1/users/1/profile-image');
  });

  testWidgets('uses paw fallback when comment avatar url is missing', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      comments: [_comment(id: 'one', userId: 'user-1')],
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('community-comment-avatar-one')),
        matching: findAppVisual(AppVisualId.communityPaw),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders two replies and the remaining reply count', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      comments: [
        _comment(
          id: 'root',
          userId: 'user-1',
          replyCount: 5,
          replies: [
            _comment(id: 'reply-1', userId: 'user-2', parentCommentId: 'root'),
            _comment(id: 'reply-2', userId: 'user-2', parentCommentId: 'root'),
            _comment(id: 'reply-3', userId: 'user-2', parentCommentId: 'root'),
          ],
        ),
      ],
    );

    expect(find.byKey(const Key('community-reply-reply-1')), findsOneWidget);
    expect(find.byKey(const Key('community-reply-reply-2')), findsOneWidget);
    expect(find.byKey(const Key('community-reply-reply-3')), findsNothing);
    expect(find.text('답글 3개 더보기'), findsOneWidget);
  });

  testWidgets(
    'detail management deletes selected comment and refreshes on return',
    (tester) async {
      final service = _FakeCommunityService(
        post: _post(userId: 'post-owner'),
        comments: [_comment(id: 'own', userId: 'comment-owner')],
      );
      final router = GoRouter(
        initialLocation: '/community/posts/post-1',
        routes: [
          GoRoute(
            path: '/community/posts/:postId',
            builder: (_, _) => const CommunityDetailScreen(postId: 'post-1'),
          ),
          GoRoute(
            path: '/community/posts/:postId/comments',
            builder: (_, state) => CommunityCommentsScreen(
              postId: 'post-1',
              initialThreadId: state.uri.queryParameters['thread'],
              targetCommentId: state.uri.queryParameters['targetComment'],
              manageTarget: state.uri.queryParameters['manage'] == 'true',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await _pumpDetail(
        tester,
        router: router,
        currentUserId: 'comment-owner',
        service: service,
      );
      await tester.tap(find.byKey(const Key('community-comment-more-own')));
      await tester.pumpAndSettle();
      expect(find.text('수정하기'), findsOneWidget);
      await tester.tap(find.text('삭제하기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('community-comment-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(service.deletedIds, ['own']);
      await tester.tap(find.byKey(const Key('community-comments-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community-comment-more-own')), findsNothing);
      expect(find.text('소중한 첫 댓글을 남겨주세요'), findsOneWidget);
    },
  );
  testWidgets('renders deleted preview root as tombstone without actions', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      post: _post(userId: 'post-owner', commentsCount: 0),
      comments: [
        _comment(
          id: 'root',
          userId: '',
          deleted: true,
          replies: [
            _comment(
              id: 'reply',
              userId: 'reply-owner',
              parentCommentId: 'root',
            ),
          ],
        ),
      ],
    );

    expect(find.text('삭제된 댓글입니다'), findsOneWidget);
    expect(find.byKey(const Key('community-comment-more-root')), findsNothing);
    expect(find.byKey(const Key('community-comment-reply-root')), findsNothing);
    expect(find.byKey(const Key('community-reply-reply')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}

Future<void> _expectKeyboardRing(WidgetTester tester, Key key) async {
  final target = find.byKey(key).first;
  final before = tester.getSize(target);
  final ring = find.descendant(
    of: target,
    matching: find.byWidgetPredicate(
      (widget) => widget is AppFocusRing && widget.focused,
    ),
  );
  for (var i = 0; i < 24 && ring.evaluate().isEmpty; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(ring, findsOneWidget);
  expect(tester.getSize(target), before);
  expect(
    find.descendant(
      of: ring,
      matching: find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.foregroundPainter != null,
      ),
    ),
    findsOneWidget,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  GoRouter? router,
  String currentUserId = 'user-1',
  Post? post,
  List<PostComment>? comments,
  _FakeCommunityService? service,
}) async {
  final resolvedService =
      service ??
      _FakeCommunityService(
        post: post ?? _post(userId: 'user-1'),
        comments: comments ?? const [],
      );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.test(
            AuthState(
              isLoading: false,
              isAuthenticated: true,
              profile: UserProfile(
                id: currentUserId,
                email: '$currentUserId@example.test',
                nickname: '사용자',
              ),
            ),
          ),
        ),
        communityServiceProvider.overrideWithValue(resolvedService),
      ],
      child: router == null
          ? const MaterialApp(home: CommunityDetailScreen(postId: 'post-1'))
          : MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Post _post({required String userId, int commentsCount = 1}) => Post(
  id: 'post-1',
  userId: userId,
  authorNickname: 'Momo',
  title: '상세 글',
  content: '내용',
  category: 'FREE',
  likesCount: 0,
  liked: false,
  commentsCount: commentsCount,
  imageUrls: const [],
  createdAt: '2026-06-24T00:00:00',
);

PostComment _comment({
  required String id,
  required String userId,
  String? authorProfileImageUrl,
  String? parentCommentId,
  int replyCount = 0,
  List<PostComment> replies = const [],
  bool deleted = false,
}) => PostComment(
  id: id,
  userId: userId,
  authorProfileImageUrl: authorProfileImageUrl,
  authorNickname: '댓글러',
  content: '댓글 내용',
  createdAt: '2026-06-24T00:00:00',
  commentsCount: 1,
  parentCommentId: parentCommentId,
  replyCount: replyCount,
  replies: replies,
  deleted: deleted,
);

class _FakeCommunityService extends CommunityService {
  final Post post;
  final List<PostComment> comments;
  final deletedIds = <String>[];
  @override
  Future<void> deleteComment(String postId, String commentId) async {
    deletedIds.add(commentId);
  }

  int? lastCommentsLimit;
  int? lastReplyLimit;

  _FakeCommunityService({required this.post, required this.comments});

  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) async => const PostFeed(items: [], nextCursor: null);

  @override
  Future<Post> getPost(String postId) async => post;

  @override
  Future<PostCommentFeed> getComments(
    String postId, {
    String? cursor,
    int limit = 20,
    int replyLimit = 20,
  }) async {
    lastCommentsLimit = limit;
    lastReplyLimit = replyLimit;
    return PostCommentFeed(
      items: comments.where((c) => !deletedIds.contains(c.id)).toList(),
    );
  }
}

class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}
