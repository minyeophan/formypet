import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/blocked_users_provider.dart';
import 'package:frontend/providers/content_visibility_provider.dart';
import 'package:frontend/screens/my/my_blocked_users_screen.dart';
import 'package:frontend/services/community_safety_service.dart';
import 'package:frontend/widgets/user_block_sheet.dart';

class BlockAuth extends AuthNotifier {
  BlockAuth() : super.test(session('viewer'));
  static AuthState session(String id) => AuthState(
    isLoading: false,
    isAuthenticated: true,
    profile: UserProfile(id: id, email: '$id@test.local', nickname: id),
  );
  void switchTo(String id) => state = session(id);
}

class BlockService extends CommunitySafetyService {
  List<BlockedUser> items = [
    const BlockedUser(userId: 'author', nickname: '차단한 집사'),
  ];
  bool failLoad = false;
  int loads = 0;
  int calls = 0;
  final pending = <Completer<void>>[];
  @override
  Future<List<BlockedUser>> getBlockedUsers() async {
    loads++;
    if (failLoad) throw Exception('offline');
    return List.of(items);
  }

  @override
  Future<void> unblock(String userId) {
    calls++;
    final result = Completer<void>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<void> block(String userId) => unblock(userId);
}

class DelayedListService extends CommunitySafetyService {
  final requests = <Completer<List<BlockedUser>>>[];
  @override
  Future<List<BlockedUser>> getBlockedUsers() {
    final request = Completer<List<BlockedUser>>();
    requests.add(request);
    return request.future;
  }
}

Future<void> pumpList(
  WidgetTester tester,
  BlockService service, {
  BlockAuth? auth,
  Widget? home,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((_) => auth ?? BlockAuth()),
        communitySafetyServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(home: home ?? const MyBlockedUsersScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('removed sheet completion is rejected after account A-B-A', (
    tester,
  ) async {
    final auth = BlockAuth();
    final service = BlockService();
    await pumpList(
      tester,
      service,
      auth: auth,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showUserBlockSheet(context, user: service.items.single),
            child: const Text('open block'),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('open block')),
    );
    await tester.tap(find.text('open block'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-block-confirm')));
    await tester.pumpAndSettle();
    final session = container.read(contentAccountSessionProvider);
    final sheetContext = tester.element(
      find.byKey(const Key('user-block-confirm')),
    );
    Navigator.of(sheetContext).removeRoute(ModalRoute.of(sheetContext)!);
    await tester.pumpAndSettle();
    auth.switchTo('B');
    auth.switchTo('viewer');
    service.pending.single.complete();
    await tester.pumpAndSettle();
    expect(container.read(contentAccountSessionProvider), isNot(same(session)));
    expect(container.read(contentVisibilityRevisionProvider), 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'overlapping same-session successes each invalidate after route removal',
    (tester) async {
      final service = BlockService();
      await pumpList(
        tester,
        service,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showUserBlockSheet(context, user: service.items.single),
              child: const Text('open block'),
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('open block')),
      );
      final session = container.read(contentAccountSessionProvider);
      final initialRevision = container.read(contentVisibilityRevisionProvider);
      await tester.tap(find.text('open block'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('user-block-confirm')));
      await tester.pumpAndSettle();
      final sheetContext = tester.element(
        find.byKey(const Key('user-block-confirm')),
      );
      Navigator.of(sheetContext).removeRoute(ModalRoute.of(sheetContext)!);
      await tester.pumpAndSettle();
      await tester.tap(find.text('open block'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('user-block-confirm')));
      await tester.pumpAndSettle();
      expect(service.pending, hasLength(2));
      service.pending.last.complete();
      await tester.pumpAndSettle();
      expect(
        container.read(contentVisibilityRevisionProvider),
        initialRevision + 1,
      );
      service.pending.first.complete();
      await tester.pumpAndSettle();
      expect(
        container.read(contentVisibilityRevisionProvider),
        initialRevision + 2,
      );
      expect(container.read(contentAccountSessionProvider), same(session));
      expect(find.byKey(const Key('user-block-confirm')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'late previous-account list cannot replace current-account list',
    () async {
      final auth = BlockAuth();
      final service = DelayedListService();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((_) => auth),
          communitySafetyServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(blockedUsersProvider, (_, _) {});
      addTearDown(listener.close);
      expect(service.requests, hasLength(1));
      auth.switchTo('new-account');
      final current = container.read(blockedUsersProvider.future);
      expect(service.requests, hasLength(2));
      service.requests.last.complete([
        const BlockedUser(userId: 'new', nickname: '새 계정 목록'),
      ]);
      await current;
      service.requests.first.complete([
        const BlockedUser(userId: 'old', nickname: '이전 계정 목록'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(blockedUsersProvider).requireValue.single.userId,
        'new',
      );
    },
  );
  testWidgets('empty list and load failure retry', (tester) async {
    final service = BlockService()..failLoad = true;
    await pumpList(tester, service);
    expect(find.text('차단 목록을 불러오지 못했어요.'), findsOneWidget);
    service.failLoad = false;
    service.items = [];
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
    expect(service.loads, 2);
  });

  testWidgets('failed unblock retains row then successful retry refreshes', (
    tester,
  ) async {
    final service = BlockService();
    await pumpList(tester, service);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyBlockedUsersScreen)),
    );
    final revision = container.read(contentVisibilityRevisionProvider);
    await tester.tap(find.text('차단 해제'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('user-block-confirm'));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    expect(service.calls, 1);
    service.pending.single.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(container.read(contentVisibilityRevisionProvider), revision);
    expect(find.text('차단을 해제하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byKey(const Key('blocked-user-author')), findsOneWidget);
    expect(find.text('차단을 해제했어요.'), findsNothing);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    service.items = [];
    service.pending.last.complete();
    await tester.pumpAndSettle();
    expect(container.read(contentVisibilityRevisionProvider), revision + 1);
    expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
    expect(find.text('차단을 해제했어요.'), findsOneWidget);
  });

  testWidgets('cancel makes no request', (tester) async {
    final service = BlockService();
    await pumpList(tester, service);
    await tester.tap(find.text('차단 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.byKey(const Key('blocked-user-author')), findsOneWidget);
  });

  testWidgets('account switch ignores pending block and disables old dialog', (
    tester,
  ) async {
    final service = BlockService();
    final auth = BlockAuth();
    await pumpList(
      tester,
      service,
      auth: auth,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showUserBlockSheet(context, user: service.items.single),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-block-confirm')));
    await tester.pumpAndSettle();
    auth.switchTo('another');
    await tester.pumpAndSettle();
    service.pending.single.complete();
    await tester.pumpAndSettle();
    expect(find.text('계정이 변경됐어요. 목록이나 게시글에서 다시 열어 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('user-block-confirm')))
          .onPressed,
      isNull,
    );
  });
}
