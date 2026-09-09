import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_ink_well.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/screens/community/community_search_screen.dart';
import 'package:frontend/screens/community/post_card.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
  });

  testWidgets('search like updates shared feed and detail cache', (
    tester,
  ) async {
    dio.httpClientAdapter = _SearchAdapter((request) async {
      if (request.method == 'GET') return _feed([_post()]);
      return _json({'liked': true, 'likesCount': 18});
    });
    final container = await _pumpSearch(tester);
    container.read(communityProvider);
    await tester.pumpAndSettle();
    await _search(tester);

    await tester.tap(_likeButton());
    await tester.pumpAndSettle();

    expect(
      container.read(communityProvider).postsById['search-post']!.liked,
      isTrue,
    );
    expect(
      container
          .read(communityProvider)
          .postsForFeed('popular')
          .single
          .likesCount,
      18,
    );
  });

  for (final likeFirst in [true, false]) {
    testWidgets('overlapping search preserves like (like first: $likeFirst)', (
      tester,
    ) async {
      final searchResponse = Completer<ResponseBody>();
      final likeResponse = Completer<ResponseBody>();
      var searches = 0;
      dio.httpClientAdapter = _SearchAdapter((request) async {
        if (request.method == 'POST') return likeResponse.future;
        if (request.queryParameters['keyword'] == null) return _feed([]);
        if (++searches == 1) return _feed([_post()]);
        return searchResponse.future;
      });
      final container = await _pumpSearch(tester);
      await _search(tester);
      await tester.tap(_likeButton());
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('community-search-field')),
        '새로운 산책',
      );
      await tester.tap(find.byKey(const Key('community-search-submit-button')));
      await tester.pump();

      if (likeFirst) {
        likeResponse.complete(_json({'liked': true, 'likesCount': 18}));
        await tester.pump();
      }
      searchResponse.complete(_feed([_post(title: '새 제목', commentsCount: 11)]));
      await tester.pumpAndSettle();
      if (!likeFirst) {
        likeResponse.complete(_json({'liked': true, 'likesCount': 18}));
        await tester.pumpAndSettle();
      }

      expect(_card(tester).post.liked, isTrue);
      expect(_card(tester).post.likesCount, 18);
      expect(_card(tester).post.title, '새 제목');
      expect(_card(tester).post.commentsCount, 11);
      expect(
        container.read(communityProvider).postsById['search-post']?.liked,
        isTrue,
      );
    });
  }

  testWidgets('new search after clearing ignores the old pending response', (
    tester,
  ) async {
    final response = Completer<ResponseBody>();
    dio.httpClientAdapter = _SearchAdapter((request) async {
      if (request.queryParameters['keyword'] == null) return _feed([]);
      if (request.queryParameters['keyword'] == '새 검색') {
        return _feed([_post(title: '새 결과')]);
      }
      return response.future;
    });
    await _pumpSearch(tester);
    await tester.enterText(
      find.byKey(const Key('community-search-field')),
      '산책',
    );
    await tester.tap(find.byKey(const Key('community-search-submit-button')));
    await tester.pump();
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('community-search-field')),
      '새 검색',
    );
    await tester.tap(find.byKey(const Key('community-search-submit-button')));
    await tester.pump();
    response.complete(_feed([_post()]));
    await tester.pumpAndSettle();
    expect(find.text('새 결과'), findsOneWidget);
    expect(find.text('산책 정보'), findsNothing);
  });

  testWidgets('search like uses server values and can be toggled off', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    var likes = 0;
    dio.httpClientAdapter = _SearchAdapter((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.path == '/api/v1/posts') {
        return _feed([_post()]);
      }
      if (request.method == 'POST' &&
          request.path == '/api/v1/posts/search-post/like') {
        likes++;
        return _json({'liked': likes == 1, 'likesCount': likes == 1 ? 17 : 16});
      }
      throw StateError('Unexpected request: ${request.method} ${request.path}');
    });
    await _pumpSearch(tester);
    await _search(tester, '  산책  ');
    expect(find.text('산책 정보'), findsOneWidget);

    await tester.tap(_likeButton());
    await tester.pumpAndSettle();

    expect(_card(tester).post.liked, isTrue);
    expect(
      find.descendant(of: _likeButton(), matching: find.text('17')),
      findsOneWidget,
    );
    expect(
      requests
          .singleWhere(
            (request) => request.queryParameters.containsKey('keyword'),
          )
          .queryParameters,
      {'keyword': '산책', 'limit': 50, 'sort': 'latest'},
    );
    expect(requests.last.method, 'POST');
    expect(requests.last.path, '/api/v1/posts/search-post/like');

    await tester.tap(_likeButton());
    await tester.pumpAndSettle();
    expect(_card(tester).post.liked, isFalse);
    expect(
      find.descendant(of: _likeButton(), matching: find.text('16')),
      findsOneWidget,
    );
  });

  testWidgets('pending like ignores repeat taps and re-enables after success', (
    tester,
  ) async {
    final response = Completer<ResponseBody>();
    var likeRequests = 0;
    dio.httpClientAdapter = _SearchAdapter((request) async {
      if (request.method == 'GET') return _feed([_post()]);
      likeRequests++;
      return response.future;
    });
    await _pumpSearch(tester);
    await _search(tester);

    await tester.tap(_likeButton());
    await tester.tap(_likeButton());
    await tester.pumpAndSettle();
    expect(_card(tester).isLiking, isTrue);
    expect(tester.widget<AppInkWell>(_likeButton()).onTap, isNull);
    expect(likeRequests, 1);

    response.complete(_json({'liked': true, 'likesCount': 8}));
    await tester.pumpAndSettle();
    expect(_card(tester).isLiking, isFalse);
    expect(tester.widget<AppInkWell>(_likeButton()).onTap, isNotNull);
    expect(_card(tester).post.likesCount, 8);
  });

  testWidgets('failed like keeps results and permits retry with feedback', (
    tester,
  ) async {
    var likeRequests = 0;
    dio.httpClientAdapter = _SearchAdapter((request) async {
      if (request.method == 'GET') return _feed([_post()]);
      likeRequests++;
      if (likeRequests == 1) {
        return _json({'title': 'Unavailable'}, status: 503);
      }
      return _json({'liked': true, 'likesCount': 8});
    });
    await _pumpSearch(tester);
    await _search(tester);

    await tester.tap(_likeButton());
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('좋아요'), findsWidgets);
    expect(find.text('산책 정보'), findsOneWidget);
    expect(_card(tester).post.liked, isFalse);
    expect(_card(tester).post.likesCount, 7);
    expect(tester.widget<AppInkWell>(_likeButton()).onTap, isNotNull);
    expect(tester.takeException(), isNull);

    await tester.tap(_likeButton());
    await tester.pumpAndSettle();
    expect(_card(tester).post.liked, isTrue);
    expect(_card(tester).post.likesCount, 8);
  });

  testWidgets(
    'like completion preserves newer search fields for the same post',
    (tester) async {
      final response = Completer<ResponseBody>();
      var searches = 0;
      dio.httpClientAdapter = _SearchAdapter((request) async {
        if (request.method == 'GET') {
          if (request.queryParameters['keyword'] == null) return _feed([]);
          searches++;
          return _feed([
            _post(
              title: searches == 1 ? '산책 정보' : '수정된 산책 정보',
              content: searches == 1 ? '함께 산책해요' : '새로운 산책 장소',
              commentsCount: searches == 1 ? 3 : 11,
            ),
          ]);
        }
        return response.future;
      });
      await _pumpSearch(tester);
      await _search(tester);
      await tester.tap(_likeButton());
      await tester.pump();
      await _search(tester, '새로운 산책');
      expect(find.text('수정된 산책 정보'), findsOneWidget);

      response.complete(_json({'liked': true, 'likesCount': 18}));
      await tester.pumpAndSettle();

      expect(_card(tester).post.liked, isTrue);
      expect(_card(tester).post.likesCount, 18);
      expect(find.text('수정된 산책 정보'), findsOneWidget);
      expect(find.text('새로운 산책 장소'), findsOneWidget);
      expect(_card(tester).post.commentsCount, 11);
    },
  );

  testWidgets('late like response does not bring back cleared search results', (
    tester,
  ) async {
    final response = Completer<ResponseBody>();
    dio.httpClientAdapter = _SearchAdapter((request) async {
      if (request.method == 'GET') return _feed([_post()]);
      return response.future;
    });
    await _pumpSearch(tester);
    await _search(tester);
    await tester.tap(_likeButton());
    await tester.pump();
    expect(_card(tester).isLiking, isTrue);
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pumpAndSettle();

    response.complete(_json({'liked': true, 'likesCount': 8}));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsNothing);
    expect(find.text('궁금한 내용을 검색해 보세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search preserves trimmed 2 to 20 character validation', (
    tester,
  ) async {
    final keywords = <String>[];
    dio.httpClientAdapter = _SearchAdapter((request) async {
      if (request.queryParameters['keyword'] == null) return _feed([]);
      keywords.add(request.queryParameters['keyword'] as String);
      return _feed([]);
    });
    await _pumpSearch(tester);
    for (final keyword in ['', ' 가 ', '가' * 21]) {
      await _search(tester, keyword);
      expect(find.text('검색어는 2~20자로 입력해 주세요.'), findsOneWidget);
    }
    expect(keywords, isEmpty);
    await _search(tester, ' 산책 ');
    expect(find.text('검색 결과가 없어요.'), findsOneWidget);
    await _search(tester, '가' * 20);
    expect(keywords, ['산책', '가' * 20]);
  });

  testWidgets('search focus uses primary outline with stable rounded shape', (
    tester,
  ) async {
    await _pumpSearch(tester);
    var decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.isFocused, isTrue);
    final focused = decorator.decoration.focusedBorder! as OutlineInputBorder;
    expect(focused.borderSide.color, AppColors.primary);
    expect(focused.borderRadius, BorderRadius.circular(16));

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.isFocused, isFalse);
    final enabled = decorator.decoration.enabledBorder! as OutlineInputBorder;
    expect(enabled.borderRadius, focused.borderRadius);
    expect(
      (decorator.decoration.border! as OutlineInputBorder).borderRadius,
      focused.borderRadius,
    );
  });
}

Future<ProviderContainer> _pumpSearch(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          inputDecorationTheme: InputDecorationTheme(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: AppColors.actionMint),
            ),
          ),
        ),
        home: const CommunitySearchScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(CommunitySearchScreen)),
  );
}

Future<void> _search(WidgetTester tester, [String keyword = '산책']) async {
  await tester.enterText(
    find.byKey(const Key('community-search-field')),
    keyword,
  );
  await tester.tap(find.byKey(const Key('community-search-submit-button')));
  await tester.pumpAndSettle();
}

Finder _likeButton() =>
    find.byKey(const Key('community-like-button-search-post'));

PostCard _card(WidgetTester tester) =>
    tester.widget<PostCard>(find.byType(PostCard));

Map<String, dynamic> _post({
  String title = '산책 정보',
  String content = '함께 산책해요',
  int commentsCount = 3,
}) => {
  'id': 'search-post',
  'userId': 'user-1',
  'authorNickname': 'Mochi',
  'authorProfileImageUrl': null,
  'title': title,
  'content': content,
  'category': 'FREE',
  'likesCount': 7,
  'liked': false,
  'commentsCount': commentsCount,
  'mediaUrls': <String>[],
  'poll': null,
  'createdAt': '2026-05-21T12:00:00',
};

ResponseBody _feed(List<Map<String, dynamic>> posts) =>
    _json({'items': posts, 'nextCursor': null});

ResponseBody _json(Map<String, dynamic> data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

class _SearchAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;

  _SearchAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}
