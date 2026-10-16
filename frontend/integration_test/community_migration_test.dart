// Disposable local database and isolated Android package only. Use --no-uninstall.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/models/my_community_activity.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/services/pet_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('JPA community posts, reactions, threads, media and persistence', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    final directory = (await getExternalStorageDirectory())!;
    expect(directory.path, contains('com.formypet.frontend.mediatest/'));
    final fixture = File('${directory.path}/jpa-community-fixture.json');
    initApiClient('http://127.0.0.1:18083');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_COMMUNITY');
    final service = CommunityService();
    if (!existing) {
      final random = Random.secure();
      await AuthService().register(
        email:
            'community-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
        password: List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join(),
        nickname: 'JPA 커뮤니티 검증',
      );
      await PetService().createPet({'name': '커뮤니티 검증', 'species': 'dog'});
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FormypetApp(),
      ),
    );
    await _until(
      tester,
      () =>
          !container.read(authProvider).isLoading &&
          !container.read(petProvider).isLoading,
    );
    expect(container.read(authProvider).isAuthenticated, isTrue);
    final router = container.read(routerProvider);
    late String postId;
    late String photoId;
    late String rootId;
    if (!existing) {
      router.go('/community/write');
      await _until(
        tester,
        () => find
            .byKey(const Key('community-title-field'))
            .evaluate()
            .isNotEmpty,
      );
      await _text(tester, 'community-title-field', 'JPA 투표 게시글');
      await _text(tester, 'community-content-field', 'JPA 커뮤니티 본문');
      await _tap(tester, find.byKey(const Key('community-add-poll-button')));
      await _text(tester, 'community-poll-option-field-0', '산책');
      await _text(tester, 'community-poll-option-field-1', '휴식');
      await _tap(tester, find.text('등록'));
      await _until(
        tester,
        () => find.byKey(const Key('community-title-field')).evaluate().isEmpty,
      );
      final written = await service.getMyActivities(MyActivityType.written);
      final post = written.items.single.post;
      postId = post.id;
      expect(post.content, 'JPA 커뮤니티 본문');
      expect(post.poll!.options.map((o) => o.text), ['산책', '휴식']);
      router.go('/community/posts/$postId');
      await _until(
        tester,
        () => find
            .byKey(const Key('community-detail-like'))
            .evaluate()
            .isNotEmpty,
      );
      await _tap(tester, find.byKey(const Key('community-detail-like')));
      expect((await service.getPost(postId)).likesCount, 1);
      await _tap(tester, find.byKey(const Key('community-detail-like')));
      expect((await service.getPost(postId)).likesCount, 0);
      await _tap(tester, find.byKey(const Key('community-detail-like')));
      for (final option in post.poll!.options) {
        await _tap(
          tester,
          find.byKey(Key('community-poll-option-${option.id}')),
        );
        await _tap(tester, find.byKey(const Key('community-poll-submit')));
        final updated = await service.getPost(postId);
        expect(
          updated.poll!.options.singleWhere((o) => o.votedByMe).id,
          option.id,
        );
        expect(
          updated.poll!.options.fold<int>(0, (n, o) => n + o.votesCount),
          1,
        );
      }
      await _tap(tester, find.byKey(const Key('community-detail-more-button')));
      await _tap(tester, find.byKey(const Key('community-post-edit')));
      await _until(
        tester,
        () => find
            .byKey(const Key('community-title-field'))
            .evaluate()
            .isNotEmpty,
      );
      await _text(tester, 'community-title-field', 'JPA 게시글 수정');
      await _text(tester, 'community-content-field', '수정된 본문');
      await _tap(tester, find.text('저장'));
      await _until(
        tester,
        () => find.byKey(const Key('community-title-field')).evaluate().isEmpty,
      );
      expect((await service.getPost(postId)).title, 'JPA 게시글 수정');
      router.go('/community/posts/$postId/comments');
      await _until(
        tester,
        () => find
            .byKey(const Key('community-comments-input'))
            .evaluate()
            .isNotEmpty,
      );
      await _text(tester, 'community-comments-input', '부모 댓글');
      await _tap(tester, find.byKey(const Key('community-comments-submit')));
      await _until(tester, () => find.text('부모 댓글').evaluate().isNotEmpty);
      rootId = (await service.getComments(postId)).items.single.id;
      await _tap(tester, find.byKey(Key('community-comment-reply-$rootId')));
      await _text(tester, 'community-comments-input', '남아 있는 답글');
      await _tap(tester, find.byKey(const Key('community-comments-submit')));
      await _until(tester, () => find.text('남아 있는 답글').evaluate().isNotEmpty);
      await _tap(tester, find.byKey(Key('community-comment-more-$rootId')));
      await _tap(tester, find.text('수정하기'));
      await _text(tester, 'community-comments-input', '수정된 부모 댓글');
      await _tap(tester, find.byKey(const Key('community-comments-submit')));
      await _until(tester, () => find.text('수정된 부모 댓글').evaluate().isNotEmpty);
      await _tap(tester, find.byKey(Key('community-comment-more-$rootId')));
      await _tap(tester, find.text('삭제하기'));
      await _tap(
        tester,
        find.byKey(const Key('community-comment-delete-cancel')),
      );
      expect((await service.getCommentThread(postId, rootId)).deleted, isFalse);
      await _tap(tester, find.byKey(Key('community-comment-more-$rootId')));
      await _tap(tester, find.text('삭제하기'));
      await _tap(
        tester,
        find.byKey(const Key('community-comment-delete-confirm')),
      );
      await _until(tester, () => find.text('삭제된 댓글입니다').evaluate().isNotEmpty);
      expect((await service.getPost(postId)).commentsCount, 1);
      final thread = await service.getCommentThread(postId, rootId);
      expect(thread.deleted, isTrue);
      expect(thread.replies.single.content, '남아 있는 답글');

      // Exercise actual upload and image decode without depending on gallery contents.
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 16, 16),
        Paint()..color = Colors.orange,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      final photoFile = File('${directory.path}/community.png');
      await photoFile.writeAsBytes(bytes);
      final photo = await service.createPost(
        title: 'JPA 사진',
        content: '사진 유지',
        category: 'FREE',
        files: [XFile(photoFile.path, mimeType: 'image/png')],
      );
      photoId = photo.id;
      expect(photo.imageUrls, hasLength(1));
      final disposable = await service.createPost(
        title: '삭제 대상',
        content: '삭제 확인',
        category: 'FREE',
      );
      router.go('/community/posts/${disposable.id}');
      await _until(tester, () => find.text('삭제 대상').evaluate().isNotEmpty);
      await _tap(tester, find.byKey(const Key('community-detail-more-button')));
      await _tap(tester, find.byKey(const Key('community-post-delete')));
      await _tap(tester, find.text('취소'));
      expect((await service.getPost(disposable.id)).id, disposable.id);
      await _tap(tester, find.byKey(const Key('community-detail-more-button')));
      await _tap(tester, find.byKey(const Key('community-post-delete')));
      await _tap(
        tester,
        find.byKey(const Key('community-post-delete-confirm')),
      );
      await _until(
        tester,
        () => find
            .byKey(const Key('community-post-delete-confirm'))
            .evaluate()
            .isEmpty,
      );
      await expectLater(
        service.getPost(disposable.id),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            404,
          ),
        ),
      );
      final liked = await service.getMyActivities(MyActivityType.liked);
      expect(liked.items.map((e) => e.post.id), contains(postId));
      final commented = await service.getMyActivities(MyActivityType.commented);
      expect(commented.items.map((e) => e.post.id), contains(postId));
      final search = await service.getFeed(
        keyword: 'JPA 게시글 수정',
        category: 'FREE',
      );
      expect(search.items.map((p) => p.id), contains(postId));
      router.go('/my/activity?tab=liked');
      await _until(tester, () => find.text('JPA 게시글 수정').evaluate().isNotEmpty);
      await _paginationAndBlocking(tester, router, service);
      await fixture.writeAsString(
        jsonEncode({'postId': postId, 'photoId': photoId, 'rootId': rootId}),
      );
    } else {
      final data =
          jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
      postId = data['postId'] as String;
      photoId = data['photoId'] as String;
      rootId = data['rootId'] as String;
    }
    final persisted = await service.getPost(postId);
    expect(persisted.title, 'JPA 게시글 수정');
    expect(persisted.liked, isTrue);
    expect(persisted.likesCount, 1);
    expect(persisted.commentsCount, 1);
    expect(persisted.poll!.options.last.votedByMe, isTrue);
    expect(persisted.poll!.options.last.votesCount, 1);
    // Follow the real detail -> comments route. Replacing only postId on an
    // already mounted comments route retains that screen's existing state.
    router.go('/community/posts/$postId');
    await _until(tester, () => find.text('JPA 게시글 수정').evaluate().isNotEmpty);
    await _tap(tester, find.byKey(const Key('community-detail-comment-launcher')));
    await _until(tester, () => find.text('삭제된 댓글입니다').evaluate().isNotEmpty);
    expect(find.text('남아 있는 답글'), findsOneWidget);
    expect((await service.getCommentThread(postId, rootId)).deleted, isTrue);
    router.go('/community/posts/$photoId');
    await _until(
      tester,
      () => find
          .byKey(const Key('community-detail-images'))
          .evaluate()
          .isNotEmpty,
    );
    await _reveal(tester, find.byKey(const Key('community-detail-images')));
    await _until(
      tester,
      () => find
          .descendant(
            of: find.byKey(const Key('community-detail-images')),
            matching: find.byWidgetPredicate(
              (w) => w is RawImage && w.image != null,
            ),
          )
          .evaluate()
          .isNotEmpty,
    );
    expect(tester.takeException(), isNull);
    debugPrint(
      existing ? 'COMMUNITY_RESTART_VERIFIED' : 'COMMUNITY_UI_VERIFIED',
    );
  });
}

Future<void> _text(WidgetTester tester, String key, String value) async {
  final target = find.byKey(Key(key));
  await _reveal(tester, target);
  await tester.enterText(target, value);
  await _hideKeyboard(tester);
}

Future<void> _paginationAndBlocking(
  WidgetTester tester,
  GoRouter router,
  CommunityService service,
) async {
  final post = await service.createPost(
    title: '댓글 페이지 검증',
    content: '별도 테스트 게시글',
    category: 'FREE',
  );
  final root = await service.createComment(post.id, '가장 오래된 부모');
  for (var i = 0; i < 21; i++) {
    await service.createComment(post.id, '답글 $i', parentCommentId: root.id);
    await service.createComment(post.id, '페이지 부모 $i');
  }
  final first = await service.getComments(post.id);
  expect(first.items, hasLength(20));
  expect(first.nextCursor, isNotNull);
  final second = await service.getComments(post.id, cursor: first.nextCursor);
  expect(second.items, hasLength(2));
  expect(
    first.items
        .map((c) => c.id)
        .toSet()
        .intersection(second.items.map((c) => c.id).toSet()),
    isEmpty,
  );
  router.go('/community/posts/${post.id}/comments');
  await _until(tester, () => find.text('페이지 부모 20').evaluate().isNotEmpty);
  await _tap(tester, find.byKey(const Key('community-comments-load-more')));
  await _reveal(tester, find.text('가장 오래된 부모'));
  await _tap(tester, find.byKey(Key('community-replies-load-more-${root.id}')));
  await _reveal(tester, find.text('답글 0'));
  expect(find.text('답글 0'), findsOneWidget);

  // A separate HTTP client keeps the main app's persisted credentials intact.
  final other = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:18083'));
  try {
    final random = Random.secure();
    final tokens =
        unwrap(
              await other.post(
                '/api/v1/auth/register',
                data: {
                  'email':
                      'community-other-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
                  'password': List.generate(
                    32,
                    (_) => random.nextInt(16).toRadixString(16),
                  ).join(),
                  'nickname': '차단 검증 작성자',
                },
              ),
            )
            as Map<String, dynamic>;
    other.options.headers['Authorization'] = 'Bearer ${tokens['accessToken']}';
    final comment =
        unwrap(
              await other.post(
                '/api/v1/posts/${post.id}/comments',
                data: {'content': '차단 전 댓글'},
              ),
            )
            as Map<String, dynamic>;
    await service.reportComment(
      post.id,
      comment['id'].toString(),
      'OTHER',
      detail: '격리 QA 신고 검증',
    );
    await expectLater(
      service.reportComment(post.id, comment['id'].toString(), 'SPAM'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'duplicate report status',
          409,
        ),
      ),
    );
    final otherPost =
        unwrap(
              await other.post(
                '/api/v1/posts',
                data: FormData.fromMap({
                  'payload': jsonEncode({
                    'title': '차단할 게시글',
                    'content': '격리 QA',
                    'category': 'FREE',
                  }),
                }),
              ),
            )
            as Map<String, dynamic>;
    final otherId = otherPost['id'].toString();
    router.go('/community/posts/$otherId');
    await _until(tester, () => find.text('차단할 게시글').evaluate().isNotEmpty);
    await _tap(tester, find.byKey(const Key('community-detail-more-button')));
    await _tap(tester, find.byKey(const Key('community-post-block')));
    await _tap(tester, find.byKey(const Key('user-block-confirm')));
    await _until(
      tester,
      () => find.byKey(const Key('user-block-confirm')).evaluate().isEmpty,
    );
    await expectLater(
      service.getPost(otherId),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'blocked post status',
          404,
        ),
      ),
    );
    router.go('/community/posts/${post.id}/comments');
    await _until(
      tester,
      () => find.text('차단한 사용자의 댓글입니다').evaluate().isNotEmpty,
    );
    expect(find.text('차단 전 댓글'), findsNothing);
    expect((await service.getComments(post.id)).items.first.blocked, isTrue);
  } finally {
    other.close();
  }
  debugPrint('COMMUNITY_PAGINATION_BLOCK_REPORT_VERIFIED');
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _hideKeyboard(tester);
  // Community wrappers forward their key to the inner InkWell as well.
  await _reveal(tester, target);
  final control = target.first;
  expect(control.hitTestable(), findsOneWidget);
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final vertical = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(target, 180, scrollable: vertical.first);
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Community UI did not become ready');
}
