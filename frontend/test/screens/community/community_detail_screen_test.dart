import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/screens/community/community_detail_screen.dart';
import 'package:frontend/services/community_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows post more button after loading detail', (tester) async {
    await _pumpDetail(tester);

    expect(find.byKey(const Key('community-detail-back')), findsOneWidget);
    expect(
      find.byKey(const Key('community-detail-more-button')),
      findsOneWidget,
    );
  });

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

  testWidgets('delete action shows preparing toast', (tester) async {
    await _pumpDetail(
      tester,
      currentUserId: 'comment-owner',
      comments: [_comment(id: 'own', userId: 'comment-owner')],
    );

    await tester.tap(find.byKey(const Key('community-comment-more-own')));
    await tester.pumpAndSettle();
    expect(find.text('댓글 관리'), findsOneWidget);

    await tester.tap(find.text('삭제하기'));
    await tester.pump();

    expect(find.text('준비중'), findsOneWidget);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  String currentUserId = 'user-1',
  Post? post,
  List<PostComment>? comments,
}) async {
  final service = _FakeCommunityService(
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
        communityServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(home: CommunityDetailScreen(postId: 'post-1')),
    ),
  );
  await tester.pumpAndSettle();
}

Post _post({required String userId}) => Post(
  id: 'post-1',
  userId: userId,
  authorNickname: 'Momo',
  title: '상세 글',
  content: '내용',
  category: 'FREE',
  likesCount: 0,
  liked: false,
  commentsCount: 1,
  imageUrls: const [],
  createdAt: '2026-06-24T00:00:00',
);

PostComment _comment({required String id, required String userId}) =>
    PostComment(
      id: id,
      userId: userId,
      authorNickname: '댓글러',
      content: '댓글 내용',
      createdAt: '2026-06-24T00:00:00',
      commentsCount: 1,
    );

class _FakeCommunityService extends CommunityService {
  final Post post;
  final List<PostComment> comments;

  _FakeCommunityService({required this.post, required this.comments});

  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
  }) async => const PostFeed(items: [], nextCursor: null);

  @override
  Future<Post> getPost(String postId) async => post;

  @override
  Future<PostCommentFeed> getComments(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async => PostCommentFeed(items: comments);
}
