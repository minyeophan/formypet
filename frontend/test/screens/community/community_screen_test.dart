import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_v2_tokens.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/screens/community/community_screen.dart';
import 'package:frontend/screens/community/write_screen.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:frontend/widgets/app_text.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

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
    await tester.drag(_categoryCarouselScrollable(), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-category-tile-EVENT')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('community-notification-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-search-button')), findsOneWidget);
    _expectCommunityHeaderStyle(tester);
    _expectHeaderActionSurface(tester, 'community-notification-button');
    _expectHeaderActionSurface(tester, 'community-search-button');

    await tester.tap(find.byKey(const Key('community-notification-button')));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-search-button')));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);

    expect(find.byKey(const Key('community-write-fab')), findsOneWidget);
    expect(find.text('제목 없음'), findsOneWidget);
  });

  testWidgets('main popular feed renders the compact post card layout', (
    tester,
  ) async {
    final createdAt = DateTime.now()
        .subtract(const Duration(hours: 2))
        .toIso8601String();
    final post = _post(
      '본문 미리보기입니다',
      'CARE',
      id: 'popular-card-1',
      title: '우리집 케어 공유',
      authorNickname: ' Momo ',
      likesCount: 12,
      commentsCount: 54,
      imageUrls: const ['https://example.com/thumb.jpg'],
      createdAt: createdAt,
    );

    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(posts: [post]),
    );

    await tester.pumpAndSettle();

    final feed = find.byKey(const Key('community-main-popular-feed'));
    final card = find.descendant(
      of: feed,
      matching: find.byKey(
        const ValueKey('community-post-card-popular-card-1'),
      ),
    );

    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('케어')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('우리집 케어 공유')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('본문 미리보기입니다')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byKey(const Key('community-post-meta')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('54')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(CircleAvatar)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(Image)),
      findsNothing,
    );
    expect(find.text('(54)'), findsNothing);
  });

  testWidgets('post card is a flat row with V2 divider and 20px padding', (
    tester,
  ) async {
    final post = _post(
      '포커스 카드 본문',
      'CARE',
      id: 'focus-card-1',
      title: '포커스 카드',
    );

    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(posts: [post]),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(
      const ValueKey('community-post-card-focus-card-1'),
    );
    expect(
      find.descendant(of: cardFinder, matching: find.byType(Card)),
      findsNothing,
    );

    final row = tester.widget<DecoratedBox>(
      find
          .descendant(of: cardFinder, matching: find.byType(DecoratedBox))
          .first,
    );
    final decoration = row.decoration as BoxDecoration;
    expect(
      decoration.border,
      const Border(bottom: BorderSide(color: AppV2Tokens.border)),
    );

    final padding = tester.widget<Padding>(
      find.descendant(of: cardFinder, matching: find.byType(Padding)).first,
    );
    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );

    final inkWell = tester.widget<InkWell>(
      find.descendant(of: cardFinder, matching: find.byType(InkWell)).first,
    );

    expect(inkWell.hoverColor, Colors.transparent);
    expect(inkWell.focusColor, Colors.transparent);
    expect(inkWell.highlightColor, Colors.transparent);
    expect(inkWell.splashColor, AppV2Tokens.primary.withValues(alpha: 0.10));
    expect(inkWell.onFocusChange, isNotNull);

    final sizeBeforeFocus = tester.getSize(cardFinder);
    inkWell.onFocusChange!(true);
    await tester.pump();

    final focused = tester.widget<DecoratedBox>(
      find
          .descendant(of: cardFinder, matching: find.byType(DecoratedBox))
          .first,
    );
    final focusedDecoration = focused.decoration as BoxDecoration;
    expect(focusedDecoration.border!.top.width, 2);
    expect(focusedDecoration.border!.top.color, AppV2Tokens.primary);
    expect(tester.getSize(cardFinder), sizeBeforeFocus);

    tester
        .widget<InkWell>(
          find.descendant(of: cardFinder, matching: find.byType(InkWell)).first,
        )
        .onFocusChange!(false);
    await tester.pump();
  });

  testWidgets('post thumbnail is exactly 80 square and absent for text rows', (
    tester,
  ) async {
    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(
        posts: [
          _post(
            'body-1',
            'CARE',
            id: 'image-row',
            title: '한 줄 제목',
            imageUrls: const ['https://example.com/a.jpg'],
          ),
          _post('body-2', 'CARE', id: 'text-row', title: '한 줄 제목'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final imageRow = find.byKey(
      const ValueKey('community-post-card-image-row'),
    );
    final textRow = find.byKey(const ValueKey('community-post-card-text-row'));
    final thumbnail = find.descendant(
      of: imageRow,
      matching: find.byKey(const Key('community-post-thumbnail')),
    );
    expect(tester.getSize(thumbnail), const Size(80, 80));
    expect(
      find.descendant(
        of: textRow,
        matching: find.byKey(const Key('community-post-thumbnail')),
      ),
      findsNothing,
    );
    expect(
      tester.getSize(textRow).height,
      lessThan(tester.getSize(imageRow).height),
    );
  });

  testWidgets('main category carousel renders two fixed panels', (
    tester,
  ) async {
    _setMobileViewport(tester);

    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(posts: [_post('popular-1', 'CARE')]),
    );

    await tester.pumpAndSettle();

    final firstPanel = find.byKey(const Key('community-category-panel-0'));
    final secondPanel = find.byKey(const Key('community-category-panel-1'));

    expect(firstPanel, findsOneWidget);
    expect(secondPanel, findsNothing);
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
    await tester.drag(_categoryCarouselScrollable(), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-category-panel-1')), findsOneWidget);
    expect(
      find.byKey(const Key('community-category-tile-NEWS')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('community-category-tile-EVENT')),
      findsOneWidget,
    );
  });

  testWidgets('category carousel snaps back when dragged less than halfway', (
    tester,
  ) async {
    _setMobileViewport(tester);

    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(posts: [_post('popular-1', 'CARE')]),
    );
    await tester.pumpAndSettle();

    final scroller = _categoryCarouselScrollable();
    await tester.drag(scroller, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(_categoryScrollPosition(tester).pixels, closeTo(0, 0.5));
  });

  testWidgets('category carousel snaps forward when dragged past halfway', (
    tester,
  ) async {
    _setMobileViewport(tester);

    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(posts: [_post('popular-1', 'CARE')]),
    );
    await tester.pumpAndSettle();

    final scroller = _categoryCarouselScrollable();
    await tester.drag(scroller, const Offset(-240, 0));
    await tester.pumpAndSettle();

    expect(_categoryScrollPosition(tester).pixels, closeTo(390, 0.5));
  });

  testWidgets('category carousel accepts mouse drag on web', (tester) async {
    _setMobileViewport(tester);
    await _pump(
      tester,
      const CommunityScreen(),
      service: _FakeCommunityService(posts: [_post('popular-1', 'CARE')]),
    );
    await tester.pumpAndSettle();

    await tester.flingFrom(
      tester.getCenter(_categoryCarouselScrollable()),
      const Offset(-260, 0),
      1000,
      deviceKind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(_categoryScrollPosition(tester).pixels, closeTo(390, 0.5));
    expect(
      find.byKey(const Key('community-category-tile-NEWS')),
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
    'main popular feed stays isolated after category back navigation',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/community',
        routes: [
          GoRoute(
            path: '/community',
            builder: (context, state) => const CommunityScreen(),
          ),
          GoRoute(
            path: '/community/category/:category',
            builder: (context, state) => CommunityCategoryScreen(
              initialCategory: state.pathParameters['category']!,
            ),
          ),
        ],
      );

      await _pumpRouter(
        tester,
        router,
        service: _FakeCommunityService(
          postsByFeedKey: {
            'popular': [_post('popular-1', 'CARE')],
            'CARE': [_post('care-1', 'CARE')],
          },
        ),
      );
      await tester.pumpAndSettle();

      final mainFeed = find.byKey(const Key('community-main-popular-feed'));
      expect(
        find.descendant(of: mainFeed, matching: find.text('제목 없음')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('community-category-tile-CARE')));
      await tester.pumpAndSettle();

      final categoryFeed = find.byKey(const Key('community-category-feed'));
      expect(
        find.descendant(of: categoryFeed, matching: find.text('제목 없음')),
        findsOneWidget,
      );

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: mainFeed, matching: find.text('제목 없음')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: mainFeed, matching: find.text('care-1')),
        findsNothing,
      );
    },
  );

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
      expect(find.byKey(const Key('community-tab-EVENT')), findsOneWidget);
      final activeSemantics = tester.getSemantics(
        find.byKey(const Key('community-tab-CARE')),
      );
      expect(activeSemantics, isSemantics(isButton: true, isSelected: true));
      expect(find.text('제목 없음'), findsOneWidget);
    },
  );

  testWidgets('category feed uses the same compact post card layout', (
    tester,
  ) async {
    final post = _post(
      '제목 없는 글 본문',
      'CARE',
      id: 'category-card-1',
      authorNickname: '   ',
      likesCount: 7,
      commentsCount: 3,
      createdAt: '',
    );

    await _pump(
      tester,
      const CommunityCategoryScreen(initialCategory: 'CARE'),
      service: _FakeCommunityService(posts: [post]),
    );

    await tester.pumpAndSettle();

    final feed = find.byKey(const Key('community-category-feed'));
    final card = find.descendant(
      of: feed,
      matching: find.byKey(
        const ValueKey('community-post-card-category-card-1'),
      ),
    );

    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('케어')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('제목 없는 글 본문')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('익명집사')),
      findsOneWidget,
    );
    expect(find.descendant(of: card, matching: find.text('7')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('3')), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(CircleAvatar)),
      findsNothing,
    );
  });

  testWidgets('category guide is collapsed and toggles four rules', (
    tester,
  ) async {
    await _pump(
      tester,
      const CommunityCategoryScreen(initialCategory: 'CARE'),
      service: _FakeCommunityService(posts: [_post('care-1', 'CARE')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('서로를 존중하는 따뜻한 언어 사용'), findsNothing);
    await tester.tap(find.byKey(const Key('community-guide-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('서로를 존중하는 따뜻한 언어 사용'), findsOneWidget);
    expect(find.text('건강 상담은 수의사 문의 권장'), findsOneWidget);
    expect(find.text('상업적 광고·홍보 제한'), findsOneWidget);
    expect(find.text('사진과 함께 일상 공유 권장'), findsOneWidget);

    await tester.tap(find.byKey(const Key('community-guide-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('서로를 존중하는 따뜻한 언어 사용'), findsNothing);
  });

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
    _expectCommunityHeaderStyle(tester);

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

  testWidgets('category screen direct URL back falls back to community', (
    tester,
  ) async {
    await _pumpDirectCommunityRouter(
      tester,
      initialLocation: '/community/category/CARE',
      service: _FakeCommunityService(posts: [_post('care-1', 'CARE')]),
    );

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('community-root'), findsOneWidget);
  });

  testWidgets(
    'write screen shows cancel action instead of shared back button',
    (tester) async {
      await _pump(
        tester,
        const WriteScreen(),
        service: _FakeCommunityService(),
      );

      expect(find.byType(AppBackButton), findsNothing);
      expect(find.text('취소'), findsOneWidget);
    },
  );

  testWidgets('write screen direct URL cancel falls back to community', (
    tester,
  ) async {
    await _pumpDirectCommunityRouter(
      tester,
      initialLocation: '/community/write',
      service: _FakeCommunityService(),
    );

    await tester.tap(find.byKey(const Key('community-title-field')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('community-root'), findsOneWidget);
  });

  testWidgets('write screen direct URL submit falls back to community', (
    tester,
  ) async {
    final service = _FakeCommunityService();
    await _pumpDirectCommunityRouter(
      tester,
      initialLocation: '/community/write',
      service: service,
    );

    await tester.enterText(
      find.byKey(const Key('community-title-field')),
      '직접 진입',
    );
    await tester.enterText(
      find.byKey(const Key('community-content-field')),
      '등록 후 커뮤니티로 돌아갑니다.',
    );
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    expect(service.createPostCallCount, 1);
    expect(find.text('community-root'), findsOneWidget);
  });

  testWidgets('write screen enforces a thirty character title limit', (
    tester,
  ) async {
    await _pump(tester, const WriteScreen(), service: _FakeCommunityService());
    final field = find.byKey(const Key('community-title-field'));
    final textField = tester.widget<TextField>(field);
    expect(textField.maxLength, 30);
    expect(textField.maxLengthEnforcement, MaxLengthEnforcement.enforced);

    await tester.enterText(field, 'a' * 31);
    expect(tester.widget<TextField>(field).controller!.text, 'a' * 30);
  });

  testWidgets('write screen category picker updates the selected board', (
    tester,
  ) async {
    await _pump(tester, const WriteScreen(), service: _FakeCommunityService());

    expect(find.byKey(const Key('community-category-field')), findsOneWidget);
    expect(find.text('자유'), findsOneWidget);

    await tester.tap(find.byKey(const Key('community-category-field')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('community-category-sheet')), findsOneWidget);
    expect(find.byKey(const Key('community-category-wheel')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('community-category-wheel')),
      const Offset(0, 220),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-category-option-CARE')),
      findsOneWidget,
    );

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(find.text('케어'), findsOneWidget);
  });

  testWidgets('write screen category picker cancel keeps current category', (
    tester,
  ) async {
    await _pump(tester, const WriteScreen(), service: _FakeCommunityService());

    await tester.tap(find.byKey(const Key('community-category-field')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('community-category-sheet')),
        matching: find.text('취소'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('자유'), findsOneWidget);
  });

  testWidgets('write screen submits selected category, title, and content', (
    tester,
  ) async {
    final service = _FakeCommunityService();
    await _pumpWriteRouter(tester, service: service);

    await tester.tap(find.byKey(const Key('community-category-field')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('community-category-wheel')),
      const Offset(0, 220),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('community-title-field')),
      '산책 질문',
    );
    await tester.enterText(
      find.byKey(const Key('community-content-field')),
      '오늘 산책을 두 번 해도 될까요?',
    );
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    expect(service.createPostCallCount, 1);
    expect(service.lastCreatedCategory, 'CARE');
    expect(service.lastCreatedTitle, '산책 질문');
    expect(service.lastCreatedContent, '오늘 산책을 두 번 해도 될까요?');
  });

  testWidgets('write screen submits free category by default', (tester) async {
    final service = _FakeCommunityService();
    await _pumpWriteRouter(tester, service: service);

    await tester.enterText(
      find.byKey(const Key('community-title-field')),
      '자유 글',
    );
    await tester.enterText(
      find.byKey(const Key('community-content-field')),
      '기본 게시판으로 등록합니다.',
    );
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    expect(service.createPostCallCount, 1);
    expect(service.lastCreatedCategory, 'FREE');
  });

  testWidgets('write screen requires title before submit', (tester) async {
    final service = _FakeCommunityService();
    await _pump(tester, const WriteScreen(), service: service);

    await tester.enterText(
      find.byKey(const Key('community-content-field')),
      '내용만 입력했습니다.',
    );
    await tester.tap(find.text('등록'));
    await tester.pump();

    expect(find.text('제목을 입력해 주세요'), findsOneWidget);
    expect(service.createPostCallCount, 0);
  });

  testWidgets('write screen requires content before submit', (tester) async {
    final service = _FakeCommunityService();
    await _pump(tester, const WriteScreen(), service: service);

    await tester.enterText(
      find.byKey(const Key('community-title-field')),
      '제목만 입력했습니다.',
    );
    await tester.tap(find.text('등록'));
    await tester.pump();

    expect(find.text('내용을 입력해 주세요'), findsOneWidget);
    expect(service.createPostCallCount, 0);
  });

  testWidgets(
    'write screen shows thumbnail rail, tool buttons, and poll panel',
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
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.poll_outlined), findsOneWidget);

      await tester.tap(find.byKey(const Key('community-add-poll-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('community-poll-panel')), findsOneWidget);
    },
  );

  testWidgets('write screen poll button shows the poll creation mock', (
    tester,
  ) async {
    await _pump(tester, const WriteScreen(), service: _FakeCommunityService());

    await tester.tap(find.byKey(const Key('community-add-poll-button')));
    await tester.pumpAndSettle();

    final pollPanel = find.byKey(const Key('community-poll-panel'));
    expect(pollPanel, findsOneWidget);
    expect(
      find.descendant(of: pollPanel, matching: find.text('투표')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: pollPanel,
        matching: find.byKey(const Key('community-poll-close-button')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pollPanel, matching: find.text('항목 입력')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: pollPanel, matching: find.text('항목 추가')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('community-poll-note')), findsOneWidget);

    await tester.tap(find.text('항목 추가'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: pollPanel, matching: find.text('항목 입력')),
      findsNWidgets(3),
    );
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _categoryCarouselScrollable() => find.descendant(
  of: find.byKey(const Key('community-category-carousel')),
  matching: find.byType(Scrollable),
);

ScrollPosition _categoryScrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_categoryCarouselScrollable()).position;

void _expectCommunityHeaderStyle(WidgetTester tester) {
  final header = tester.widget<Container>(
    find.byKey(const Key('community-header')),
  );
  final decoration = header.decoration as BoxDecoration;
  expect(decoration.color, AppV2Tokens.background);
  expect(decoration.border, isNull);

  final title = tester.widget<AppText>(
    find.byKey(const Key('community-header-title')),
  );
  expect(title.color, AppV2Tokens.text);
  expect(title.fontSize, 22);
}

void _expectHeaderActionSurface(WidgetTester tester, String key) {
  final finder = find.byKey(Key(key));
  expect(tester.getSize(finder), const Size(44, 44));

  final container = tester.widget<Container>(
    find.descendant(of: finder, matching: find.byType(Container)).first,
  );
  final decoration = container.decoration as BoxDecoration;
  expect(decoration.color, AppV2Tokens.surface);
  expect(decoration.shape, BoxShape.circle);
  expect(decoration.border, Border.all(color: AppV2Tokens.border));

  final icon = tester.widget<Icon>(
    find.descendant(of: finder, matching: find.byType(Icon)).first,
  );
  expect(icon.size, 20);
  expect(icon.color, AppV2Tokens.textSecondary);
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

Future<void> _pumpWriteRouter(
  WidgetTester tester, {
  required _FakeCommunityService service,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/write'),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(path: '/write', builder: (context, state) => const WriteScreen()),
    ],
  );

  await _pumpRouter(tester, router, service: service);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _pumpDirectCommunityRouter(
  WidgetTester tester, {
  required String initialLocation,
  required CommunityService service,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/community',
        builder: (context, state) =>
            const Scaffold(body: Text('community-root')),
      ),
      GoRoute(
        path: '/community/category/:category',
        builder: (context, state) => CommunityCategoryScreen(
          initialCategory: state.pathParameters['category']!,
        ),
      ),
      GoRoute(
        path: '/community/write',
        builder: (context, state) => const WriteScreen(),
      ),
    ],
  );

  await _pumpRouter(tester, router, service: service);
  await tester.pumpAndSettle();
}

Post _post(
  String content,
  String category, {
  String? id,
  String authorNickname = 'Momo',
  String? title,
  int likesCount = 0,
  bool liked = false,
  int commentsCount = 0,
  List<String> imageUrls = const [],
  String createdAt = '2026-05-21T12:00:00',
}) => Post(
  id: id ?? content,
  userId: 'user-1',
  authorNickname: authorNickname,
  title: title,
  content: content,
  category: category,
  likesCount: likesCount,
  liked: liked,
  commentsCount: commentsCount,
  imageUrls: imageUrls,
  createdAt: createdAt,
);

class _FakeCommunityService extends CommunityService {
  _FakeCommunityService({
    this.posts = const [],
    this.postsByFeedKey = const {},
  });

  final List<Post> posts;
  final Map<String, List<Post>> postsByFeedKey;
  String? lastCreatedCategory;
  String? lastCreatedTitle;
  String? lastCreatedContent;
  int createPostCallCount = 0;

  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) async {
    final key = sort == CommunityFeedSort.popular
        ? 'popular'
        : category ?? 'all';
    return PostFeed(items: postsByFeedKey[key] ?? posts, nextCursor: null);
  }

  @override
  Future<Post> createPost({
    required String content,
    required String title,
    required String category,
    List<XFile> files = const [],
    PollDraft? poll,
  }) async {
    createPostCallCount++;
    lastCreatedCategory = category;
    lastCreatedTitle = title;
    lastCreatedContent = content;
    return _post(content, category);
  }
}
