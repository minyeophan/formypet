import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_v2_tokens.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/screens/community/community_comments_screen.dart';
import 'package:frontend/services/community_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('uses V2 shell and requests root replies with twenty limit', (
    tester,
  ) async {
    final service = _FakeService(comments: [_comment('1')]);
    await _pump(tester, service);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppV2Tokens.background);
    expect(scaffold.resizeToAvoidBottomInset, isFalse);
    expect(find.byKey(const Key('community-comments-header')), findsOneWidget);
    expect(find.text('댓글 (1)'), findsOneWidget);
    expect(service.commentsLimit, 20);
    expect(service.replyLimit, 20);
  });

  testWidgets(
    'sorts roots descending, replies ascending and removes duplicates',
    (tester) async {
      final service = _FakeService(
        comments: [
          _comment(
            '2',
            replies: [_comment('12'), _comment('11'), _comment('11')],
          ),
          _comment('10'),
          _comment('2'),
        ],
      );
      await _pump(tester, service);

      final root10 = tester
          .getTopLeft(find.byKey(const Key('community-root-10')))
          .dy;
      final root2 = tester
          .getTopLeft(find.byKey(const Key('community-root-2')))
          .dy;
      expect(root10, lessThan(root2));
      expect(find.byKey(const Key('community-reply-11')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('community-reply-11'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('community-reply-12'))).dy,
        ),
      );
    },
  );

  testWidgets('shows preparing message for popular sort and camera', (
    tester,
  ) async {
    await _pump(tester, _FakeService());

    await tester.tap(find.byKey(const Key('community-comments-sort-popular')));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-comment-image-button')));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);
  });

  testWidgets('shows unavailable without composer for first page 404', (
    tester,
  ) async {
    await _pump(tester, _FakeService(commentsError: _dioError(404)));

    expect(find.text('게시글을 찾을 수 없습니다'), findsOneWidget);
    expect(find.byKey(const Key('community-comments-back')), findsOneWidget);
    expect(find.byKey(const Key('community-comments-composer')), findsNothing);
    expect(find.byKey(const Key('community-comments-more')), findsNothing);
  });

  testWidgets('general first page error keeps composer and retry', (
    tester,
  ) async {
    await _pump(tester, _FakeService(commentsError: Exception('offline')));

    expect(find.text('댓글을 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('재시도'), findsOneWidget);
    expect(
      find.byKey(const Key('community-comments-composer')),
      findsOneWidget,
    );
  });

  testWidgets('reply mode uses anonymous fallback and can be cancelled', (
    tester,
  ) async {
    await _pump(tester, _FakeService(comments: [_comment('1', author: '')]));

    await tester.tap(find.byKey(const Key('community-comment-reply-1')));
    await tester.pump();
    expect(find.text('익명집사님에게 답글'), findsOneWidget);
    expect(
      find.byKey(const Key('community-reply-composer-target')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('community-reply-cancel')));
    await tester.pump();
    expect(find.text('댓글을 해주세요'), findsOneWidget);
  });

  testWidgets('comment owner menu contains edit and delete only', (
    tester,
  ) async {
    await _pump(tester, _FakeService(comments: [_comment('1', userId: 'me')]));

    await tester.tap(find.byKey(const Key('community-comment-more-1')));
    await tester.pumpAndSettle();
    expect(find.text('수정하기'), findsOneWidget);
    expect(find.text('삭제하기'), findsOneWidget);
    expect(find.text('신고하기'), findsNothing);
  });

  testWidgets('renders deleted root as tombstone without actions', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeService(
        comments: [
          _comment(
            '1',
            deleted: true,
            replies: [_comment('2', userId: 'reply-owner')],
          ),
        ],
      ),
    );

    expect(find.text('삭제된 댓글입니다'), findsOneWidget);
    expect(find.byKey(const Key('community-comment-more-1')), findsNothing);
    expect(find.byKey(const Key('community-comment-reply-1')), findsNothing);
    expect(find.byKey(const Key('community-reply-2')), findsOneWidget);
    expect(find.byKey(const Key('community-comment-more-2')), findsOneWidget);
    expect(find.text('댓글 (1)'), findsOneWidget);
  });

  testWidgets('does not enter reply mode for deleted initial reply target', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeService(comments: [_comment('1', deleted: true)]),
      initialThreadId: '1',
      initialReplyToCommentId: '1',
    );

    expect(find.text('삭제된 댓글입니다'), findsOneWidget);
    expect(
      find.byKey(const Key('community-reply-composer-target')),
      findsNothing,
    );
    expect(find.text('댓글을 해주세요'), findsOneWidget);
  });

  testWidgets('comment owner can edit root comment', (tester) async {
    final service = _FakeService(comments: [_comment('1', userId: 'me')]);
    await _pump(tester, service);

    await tester.tap(find.byKey(const Key('community-comment-more-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();

    expect(find.text('댓글 수정 중'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('community-comments-input')))
          .controller
          ?.text,
      '댓글 1',
    );

    await tester.enterText(
      find.byKey(const Key('community-comments-input')),
      '수정 댓글',
    );
    service.updatedComment = _comment('1', userId: 'me', content: '수정 댓글');
    await tester.tap(find.byKey(const Key('community-comments-submit')));
    await tester.pumpAndSettle();

    expect(service.updateRequests, [('post-1', '1', '수정 댓글')]);
    expect(find.text('수정 댓글'), findsOneWidget);
    expect(find.text('댓글 수정 중'), findsNothing);
  });

  testWidgets('deleting root with replies keeps tombstone and reply', (
    tester,
  ) async {
    final service = _FakeService(
      comments: [
        _comment('1', userId: 'me', replies: [_comment('2', userId: 'other')]),
      ],
    );
    await _pump(tester, service);

    await tester.tap(find.byKey(const Key('community-comment-more-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-comment-delete-confirm')));
    await tester.pumpAndSettle();

    expect(service.deleteRequests, [('post-1', '1')]);
    expect(find.text('삭제된 댓글입니다'), findsOneWidget);
    expect(find.byKey(const Key('community-reply-2')), findsOneWidget);
    expect(find.byKey(const Key('community-comment-more-1')), findsNothing);
    expect(find.text('댓글 (1)'), findsOneWidget);
  });

  testWidgets('deleting reply removes it and decrements count', (tester) async {
    final service = _FakeService(
      comments: [
        _comment('1', replies: [_comment('2', userId: 'me')]),
      ],
    );
    await _pump(tester, service);

    await tester.tap(find.byKey(const Key('community-comment-more-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-comment-delete-confirm')));
    await tester.pumpAndSettle();

    expect(service.deleteRequests, [('post-1', '2')]);
    expect(find.byKey(const Key('community-reply-2')), findsNothing);
    expect(find.text('댓글 (1)'), findsOneWidget);
  });

  testWidgets('post owner sees delete only for another user comment', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeService(comments: [_comment('1', userId: 'other')]),
      currentUserId: 'post-owner',
    );

    await tester.tap(find.byKey(const Key('community-comment-more-1')));
    await tester.pumpAndSettle();

    expect(find.text('삭제하기'), findsOneWidget);
    expect(find.text('수정하기'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeService service, {
  String? initialThreadId,
  String? initialReplyToCommentId,
  String currentUserId = 'me',
}) async {
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
                nickname: '나',
              ),
            ),
          ),
        ),
        communityServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        home: CommunityCommentsScreen(
          postId: 'post-1',
          initialThreadId: initialThreadId,
          initialReplyToCommentId: initialReplyToCommentId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Post _post() => const Post(
  id: 'post-1',
  userId: 'post-owner',
  authorNickname: '글쓴이',
  title: '글',
  content: '본문',
  category: 'FREE',
  likesCount: 0,
  liked: false,
  commentsCount: 0,
  imageUrls: [],
  createdAt: '2026-07-08T00:00:00Z',
);

PostComment _comment(
  String id, {
  String userId = 'other',
  String author = '댓글러',
  String? content,
  int? commentsCount,
  List<PostComment> replies = const [],
  bool deleted = false,
}) => PostComment(
  id: id,
  userId: userId,
  authorNickname: author,
  content: content ?? '댓글 $id',
  createdAt: '2026-07-08T00:00:00Z',
  commentsCount: commentsCount ?? (deleted ? replies.length : 1 + replies.length),
  replies: replies,
  replyCount: replies.length,
  deleted: deleted,
);

DioException _dioError(int status) => DioException(
  requestOptions: RequestOptions(path: '/comments'),
  response: Response(
    requestOptions: RequestOptions(path: '/comments'),
    statusCode: status,
  ),
);

class _FakeService extends CommunityService {
  _FakeService({this.comments = const [], this.commentsError});

  final List<PostComment> comments;
  final Object? commentsError;
  int? commentsLimit;
  int? replyLimit;
  final List<(String postId, String commentId, String content)> updateRequests =
      [];
  final List<(String postId, String commentId)> deleteRequests = [];
  PostComment? updatedComment;
  Object? updateError;
  Object? deleteError;

  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) async => const PostFeed(items: []);

  @override
  Future<Post> getPost(String postId) async => _post();

  @override
  Future<PostCommentFeed> getComments(
    String postId, {
    String? cursor,
    int limit = 20,
    int replyLimit = 20,
  }) async {
    commentsLimit = limit;
    this.replyLimit = replyLimit;
    if (commentsError != null) throw commentsError!;
    return PostCommentFeed(items: comments);
  }

  @override
  Future<PostComment> updateComment(
    String postId,
    String commentId,
    String content,
  ) async {
    updateRequests.add((postId, commentId, content));
    if (updateError != null) throw updateError!;
    return updatedComment ?? _comment(commentId, content: content);
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    deleteRequests.add((postId, commentId));
    if (deleteError != null) throw deleteError!;
  }
}
