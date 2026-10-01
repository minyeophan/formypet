import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/community/community_comments_screen.dart';

void main() {
  setUpAll(() {
    initApiClient('https://example.test', includeAuthInterceptor: false);
  });

  for (final mode in ['comment', 'reply', 'edit']) {
    for (final succeeds in [true, false]) {
      testWidgets(
        '$mode composer locks during send and restores after success=$succeeds',
        (tester) async {
          final response = Completer<ResponseBody>();
          final writes = <RequestOptions>[];
          dio.httpClientAdapter = _Api((request) async {
            if (request.method != 'GET') {
              writes.add(request);
              return response.future;
            }
            if (request.path.endsWith('/comments')) {
              return _json({
                'items': [_comment],
                'nextCursor': null,
              });
            }
            if (request.path.endsWith('/post-1')) return _json(_post);
            if (request.path == '/api/v1/posts') {
              return _json({'items': [], 'nextCursor': null});
            }
            throw StateError('Unexpected request: ${request.path}');
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(
                  (ref) => AuthNotifier.test(
                    const AuthState(
                      isLoading: false,
                      isAuthenticated: true,
                      profile: UserProfile(
                        id: 'me',
                        email: 'me@example.test',
                        nickname: '나',
                      ),
                    ),
                  ),
                ),
              ],
              child: const MaterialApp(
                home: CommunityCommentsScreen(postId: 'post-1'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (mode == 'reply') {
            await tester.tap(
              find.byKey(const Key('community-comment-reply-c1')),
            );
            await tester.pump();
          } else if (mode == 'edit') {
            await tester.tap(
              find.byKey(const Key('community-comment-more-c1')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('수정하기'));
            await tester.pumpAndSettle();
          }
          final input = find.byKey(const Key('community-comments-input'));
          await tester.enterText(input, '보낼 내용');
          await tester.pump();
          await tester.tap(find.byKey(const Key('community-comments-submit')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 20));

          expect(writes.single.method, mode == 'edit' ? 'PATCH' : 'POST');
          expect(tester.widget<TextField>(input).enabled, isFalse);
          expect(writes.single.data, {
            'content': '보낼 내용',
            if (mode == 'reply') 'parentCommentId': 'c1',
          });
          if (mode != 'comment') {
            await tester.tap(find.byKey(const Key('community-reply-cancel')));
            await tester.pump();
            expect(
              find.byKey(const Key('community-reply-composer-target')),
              findsOneWidget,
            );
          }
          response.complete(
            succeeds
                ? _json({
                    ..._comment,
                    'id': mode == 'edit' ? 'c1' : 'c2',
                    'content': '보낼 내용',
                    'parentCommentId': mode == 'reply' ? 'c1' : null,
                    'commentsCount': 2,
                  })
                : _json({'title': 'Unavailable'}, status: 503),
          );
          await tester.pumpAndSettle();

          expect(tester.widget<TextField>(input).enabled, isTrue);
          expect(
            tester.widget<TextField>(input).controller!.text,
            succeeds ? '' : '보낼 내용',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

const _post = {
  'id': 'post-1',
  'userId': 'me',
  'authorNickname': 'Author',
  'authorProfileImageUrl': null,
  'title': 'Title',
  'content': 'Body',
  'category': 'FREE',
  'likesCount': 0,
  'liked': false,
  'commentsCount': 1,
  'mediaUrls': <String>[],
  'poll': null,
  'createdAt': '2026-09-08T12:00:00',
};
const _comment = {
  'id': 'c1',
  'userId': 'me',
  'authorNickname': 'Author',
  'content': '원래 댓글',
  'authorProfileImageUrl': null,
  'createdAt': '2026-09-08T12:00:00',
  'commentsCount': 1,
  'parentCommentId': null,
  'replyCount': 0,
  'replies': <Object>[],
  'repliesNextCursor': null,
  'deleted': false,
};
ResponseBody _json(Map<String, dynamic> data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _Api implements HttpClientAdapter {
  _Api(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}
