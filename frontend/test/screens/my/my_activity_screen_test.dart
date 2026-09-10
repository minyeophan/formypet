import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/models/my_community_activity.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/providers/my_activity_provider.dart';
import 'package:frontend/screens/my/my_activity_screen.dart';
import 'package:frontend/screens/community/community_comments_screen.dart';
import 'package:frontend/screens/community/community_detail_screen.dart';
import 'package:frontend/services/community_service.dart';

void main() {
  testWidgets(
    'detail like refreshes a visited tab whose initial response is pending',
    (tester) async {
      final initial = Completer<MyActivityPage>();
      final service = ActivityService()
        ..firstLikedResponse = initial
        ..likeResult = true;
      final router = await pump(tester, service, tab: 'liked', settle: false);
      await tester.tap(find.text('내가 쓴 글'));
      for (
        var i = 0;
        i < 20 && find.text('written 제목').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(MyActivityScreen)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('written 제목'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('상세'), findsOneWidget);
      await scope.read(communityProvider.notifier).toggleLike('written');
      router.pop();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      initial.complete(const MyActivityPage([], null));
      await tester.pumpAndSettle();
      await tester.tap(find.text('공감한 글'));
      await tester.pumpAndSettle();
      expect(find.text('written 제목'), findsOneWidget);
    },
  );
  testWidgets('late detail failure never closes a route pushed above it', (
    tester,
  ) async {
    final pending = Completer<Post>();
    final service = ActivityService()..pendingDetail = pending;
    final router = await pump(tester, service, realDetail: true);
    await tester.tap(find.text('written 제목'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CommunityDetailScreen), findsOneWidget);
    unawaited(router.push('/community/posts/written/comments'));
    await tester.pumpAndSettle();
    service.postMissing = true;
    pending.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/posts'),
        response: Response(
          requestOptions: RequestOptions(path: '/posts'),
          statusCode: 404,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('destination-uri')), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MyActivityScreen), findsOneWidget);
    expect(find.text('아직 작성한 글이 없어요.'), findsOneWidget);
  });
  testWidgets(
    'post removed between availability check and detail returns to activity',
    (tester) async {
      final service = ActivityService()..disappearOnDetail = true;
      await pump(tester, service, realDetail: true);
      await tester.tap(find.text('written 제목'));
      await tester.pumpAndSettle();
      expect(find.byType(MyActivityScreen), findsOneWidget);
      expect(find.text('아직 작성한 글이 없어요.'), findsOneWidget);
      expect(find.text('삭제되었거나 볼 수 없는 게시글이에요.'), findsOneWidget);
    },
  );
  testWidgets(
    'deleting own post returns to activity rather than resetting navigation',
    (tester) async {
      final service = ActivityService();
      await pump(tester, service, realDetail: true);
      await tester.tap(find.text('written 제목'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community-detail-more-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('게시글 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(find.byType(MyActivityScreen), findsOneWidget);
      expect(find.text('아직 작성한 글이 없어요.'), findsOneWidget);
    },
  );
  testWidgets('like supersedes pending initial liked response', (tester) async {
    final initial = Completer<MyActivityPage>();
    final service = ActivityService()
      ..firstLikedResponse = initial
      ..likeResult = true;
    await pump(tester, service, tab: 'liked', settle: false);
    await tester.tap(find.text('내가 쓴 글'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (
      var i = 0;
      i < 20 &&
          find
              .byKey(const ValueKey('community-like-button-written'))
              .evaluate()
              .isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(
      find.byKey(const ValueKey('community-like-button-written')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    initial.complete(const MyActivityPage([], null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공감한 글'));
    await tester.pumpAndSettle();
    expect(find.text('written 제목'), findsOneWidget);
  });
  testWidgets('switching tabs preserves scroll and loaded content', (
    tester,
  ) async {
    final service = ActivityService();
    service.writtenSnapshot = List.generate(
      15,
      (index) => MyCommunityActivity(
        post: service.post('written-$index'),
        activityAt: '2026-09-10T12:00:00',
      ),
    );
    await pump(tester, service);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final offset = tester
        .widget<ListView>(find.byType(ListView).first)
        .controller!
        .offset;
    expect(offset, greaterThan(0));
    await tester.tap(find.text('공감한 글'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내가 쓴 글'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListView>(find.byType(ListView).first).controller!.offset,
      offset,
    );
    expect(service.calls[MyActivityType.written], 1);
  });
  testWidgets(
    'new like refreshes previously visited liked tab with server activity time',
    (tester) async {
      final service = ActivityService()
        ..likedSnapshot = []
        ..likeResult = true;
      await pump(tester, service, tab: 'liked');
      expect(find.text('아직 공감한 글이 없어요.'), findsOneWidget);
      await tester.tap(find.text('내가 쓴 글'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('community-like-button-written')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('공감한 글'));
      await tester.pumpAndSettle();
      expect(find.text('written 제목'), findsOneWidget);
    },
  );
  testWidgets(
    'deleted target comment falls back to post; missing post removes activity',
    (tester) async {
      final service = ActivityService();
      final router = await pump(
        tester,
        service,
        tab: 'commented',
        realComments: true,
      );
      await tester.tap(find.text('내 댓글 · 내 답글'));
      await tester.pumpAndSettle();
      expect(find.text('상세'), findsOneWidget);
      expect(find.text('댓글이 삭제되어 게시글로 이동합니다.'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      service.postMissing = true;
      final before = service.postRequests;
      await tester.tap(find.text('commented 제목'));
      await tester.pumpAndSettle();
      expect(
        service.postRequests,
        before + 1,
        reason: 'second tap must check post availability after returning',
      );
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(MyActivityScreen)),
      );
      expect(
        scope.read(myActivityProvider(MyActivityType.commented)).items,
        isEmpty,
      );
      expect(find.text('아직 댓글을 남긴 글이 없어요.'), findsOneWidget);
    },
  );
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final type in MyActivityType.values) {
    testWidgets('opens ${type.name} and shows its activity metadata', (
      tester,
    ) async {
      final service = ActivityService();
      await pump(tester, service, tab: type.name);
      expect(find.text('${type.name} 제목'), findsOneWidget);
      if (type == MyActivityType.commented) {
        expect(find.text('내 댓글 · 내 답글'), findsOneWidget);
      }
    });
  }
  testWidgets('invalid tab defaults to written and visited tabs retain lists', (
    tester,
  ) async {
    final service = ActivityService();
    await pump(tester, service, tab: 'bad');
    expect(find.text('written 제목'), findsOneWidget);
    await tester.tap(find.text('공감한 글'));
    await tester.pumpAndSettle();
    expect(find.text('liked 제목'), findsOneWidget);
    await tester.tap(find.text('내가 쓴 글'));
    await tester.pumpAndSettle();
    expect(service.calls[MyActivityType.written], 1);
  });
  testWidgets('like failure keeps item; successful unlike removes it', (
    tester,
  ) async {
    final service = ActivityService()..likeFails = true;
    await pump(tester, service, tab: 'liked');
    final like = find.byKey(const ValueKey('community-like-button-liked'));
    await tester.tap(like);
    await tester.pumpAndSettle();
    expect(find.text('liked 제목'), findsOneWidget);
    expect(find.text('공감을 변경하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    service.likeFails = false;
    await tester.tap(like);
    await tester.pumpAndSettle();
    expect(find.text('아직 공감한 글이 없어요.'), findsOneWidget);
  });
  testWidgets('card opens detail and preview targets reply without composing', (
    tester,
  ) async {
    final service = ActivityService();
    final router = await pump(tester, service, tab: 'commented');
    await tester.tap(find.text('commented 제목'));
    await tester.pumpAndSettle();
    expect(find.text('상세'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 댓글 · 내 답글'));
    await tester.pumpAndSettle();
    final uri = Uri.parse(
      tester.widget<Text>(find.byKey(const Key('destination-uri'))).data!,
    );
    expect(uri.path, '/community/posts/commented/comments');
    expect(uri.queryParameters['thread'], '10');
    expect(uri.queryParameters['targetComment'], '11');
    expect(uri.queryParameters.containsKey('replyTo'), isFalse);
  });
  testWidgets('initial failure retries and refresh failure retains content', (
    tester,
  ) async {
    final service = ActivityService()..fails = true;
    await pump(tester, service);
    expect(find.text('다시 시도'), findsOneWidget);
    service.fails = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('written 제목'), findsOneWidget);
    service.fails = true;
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('written 제목'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });
  testWidgets('narrow display and large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, ActivityService(), scale: 2);
    expect(tester.takeException(), isNull);
  });
}

Future<GoRouter> pump(
  WidgetTester tester,
  ActivityService service, {
  String tab = 'written',
  double scale = 1,
  bool realComments = false,
  bool realDetail = false,
  bool settle = true,
}) async {
  final router = GoRouter(
    initialLocation: '/my/activity?tab=$tab',
    routes: [
      GoRoute(
        path: '/my/activity',
        builder: (_, state) =>
            MyActivityScreen(initialTab: state.uri.queryParameters['tab']!),
      ),
      GoRoute(
        path: '/community/posts/:id',
        builder: (_, state) => realDetail
            ? CommunityDetailScreen(postId: state.pathParameters['id']!)
            : const Scaffold(body: Text('상세')),
      ),
      GoRoute(
        path: '/community/posts/:id/comments',
        builder: (_, state) => realComments
            ? CommunityCommentsScreen(
                postId: state.pathParameters['id']!,
                initialThreadId: state.uri.queryParameters['thread'],
                targetCommentId: state.uri.queryParameters['targetComment'],
              )
            : Scaffold(
                body: Text(
                  state.uri.toString(),
                  key: const Key('destination-uri'),
                ),
              ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityServiceProvider.overrideWithValue(service),
        authProvider.overrideWith(
          (_) => AuthNotifier.test(
            const AuthState(
              isLoading: false,
              isAuthenticated: true,
              profile: UserProfile(
                id: 'me',
                email: 'me@example.com',
                nickname: 'me',
              ),
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return router;
}

class ActivityService extends CommunityService {
  Completer<Post>? pendingDetail;
  bool disappearOnDetail = false;
  Completer<MyActivityPage>? firstLikedResponse;
  List<MyCommunityActivity>? writtenSnapshot;
  List<MyCommunityActivity>? likedSnapshot;
  bool likeResult = false;
  int postRequests = 0;
  bool postMissing = false;
  @override
  Future<PostCommentFeed> getComments(
    String postId, {
    String? cursor,
    int limit = 20,
    int replyLimit = 20,
  }) async => const PostCommentFeed(items: []);
  @override
  Future<PostComment> getCommentThread(
    String postId,
    String commentId, {
    int replyLimit = 20,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/comments'),
      response: Response(
        requestOptions: RequestOptions(path: '/comments'),
        statusCode: 404,
      ),
    );
  }

  bool fails = false, likeFails = false;
  final calls = <MyActivityType, int>{};
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
  }) async {
    calls.update(type, (v) => v + 1, ifAbsent: () => 1);
    if (type == MyActivityType.liked && firstLikedResponse != null) {
      final pending = firstLikedResponse!;
      firstLikedResponse = null;
      return pending.future;
    }
    if (fails) throw StateError('offline');
    if (postMissing) return const MyActivityPage([], null);
    if (type == MyActivityType.written && writtenSnapshot != null) {
      return MyActivityPage(writtenSnapshot!, null);
    }
    if (type == MyActivityType.liked && likedSnapshot != null) {
      return MyActivityPage(likedSnapshot!, null);
    }
    return MyActivityPage([
      MyCommunityActivity(
        post: post(type.name),
        activityAt: '2026-09-10T12:00:00',
        commentId: type == MyActivityType.commented ? '11' : null,
        parentId: type == MyActivityType.commented ? '10' : null,
        commentContent: type == MyActivityType.commented ? '내 답글' : null,
      ),
    ], null);
  }

  @override
  Future<Map<String, dynamic>> toggleLike(String postId) async {
    if (likeFails) throw StateError('offline');
    if (likeResult) {
      likedSnapshot = [
        MyCommunityActivity(
          post: post(postId),
          activityAt: '2026-09-10T13:00:00',
        ),
      ];
    }
    return {'liked': likeResult, 'likesCount': likeResult ? 1 : 0};
  }

  @override
  Future<void> deletePost(String postId) async {
    postMissing = true;
  }

  @override
  Future<Post> getPost(String postId) async {
    postRequests++;
    if (postRequests == 2 && pendingDetail != null) {
      return pendingDetail!.future;
    }
    if (disappearOnDetail && postRequests > 1) postMissing = true;
    if (postMissing) {
      throw DioException(
        requestOptions: RequestOptions(path: '/posts'),
        response: Response(
          requestOptions: RequestOptions(path: '/posts'),
          statusCode: 404,
        ),
      );
    }
    return post(postId);
  }

  Post post(String id) => Post(
    id: id,
    userId: 'me',
    authorNickname: 'me',
    title: '$id 제목',
    content: '내용',
    category: 'FREE',
    likesCount: 1,
    liked: true,
    commentsCount: 1,
    imageUrls: [],
    createdAt: '2026-09-10T11:00:00',
  );
}
