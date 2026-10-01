import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/app_v2_tokens.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/community/post_report_screen.dart';
import 'package:frontend/services/community_safety_service.dart';

class TestAuth extends AuthNotifier {
  TestAuth() : super.test(session('viewer'));
  static AuthState session(String id) => AuthState(
    isLoading: false,
    isAuthenticated: true,
    profile: UserProfile(id: id, email: '$id@test.local', nickname: id),
  );
  void switchTo(String id) => state = session(id);
}

class ReportService extends CommunitySafetyService {
  final requests = <String>[];
  final pending = <Completer<ReportReceipt>>[];
  @override
  Future<ReportReceipt> reportPost({
    required String postId,
    required String reason,
    required String detail,
    required String requestId,
  }) {
    requests.add(requestId);
    final result = Completer<ReportReceipt>();
    pending.add(result);
    return result.future;
  }
}

const post = Post(
  id: 'post',
  userId: 'author',
  authorNickname: '집사',
  title: '게시글',
  content: '내용',
  category: 'FREE',
  likesCount: 0,
  liked: false,
  commentsCount: 0,
  imageUrls: [],
  createdAt: '',
);

Future<void> pumpReport(
  WidgetTester tester,
  ReportService service,
  TestAuth auth,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((_) => auth),
        communitySafetyServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(home: PostReportScreen(post: post)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  final button = find.byKey(const Key('report-submit'));
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('selection is green and OTHER requires detail', (tester) async {
    final service = ReportService();
    await pumpReport(tester, service, TestAuth());
    await tester.tap(find.byKey(const Key('report-reason-OTHER')));
    await tester.pump();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.radio_button_checked)).color,
      AppV2Tokens.primary,
    );
    await submit(tester);
    expect(find.text('기타 사유의 상세 내용을 입력해 주세요.'), findsOneWidget);
    expect(service.requests, isEmpty);
  });

  testWidgets(
    'failure retains draft and retries same request without duplicate submit',
    (tester) async {
      final service = ReportService();
      await pumpReport(tester, service, TestAuth());
      await tester.tap(find.byKey(const Key('report-reason-SPAM')));
      await tester.enterText(find.byKey(const Key('report-detail')), '광고 내용');
      await submit(tester);
      await submit(tester);
      expect(service.requests, hasLength(1));
      service.pending.single.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('report-detail')))
            .controller!
            .text,
        '광고 내용',
      );
      expect(find.text('신고가 접수됐어요'), findsNothing);
      await submit(tester);
      expect(service.requests, hasLength(2));
      expect(service.requests.first, service.requests.last);
      service.pending.last.complete(
        ReportReceipt(id: 'receipt-1', receivedAt: DateTime(2026)),
      );
      await tester.pumpAndSettle();
      expect(find.text('신고가 접수됐어요'), findsOneWidget);
      expect(find.text('접수번호 receipt-1'), findsOneWidget);
    },
  );

  testWidgets('account change clears draft and ignores pending receipt', (
    tester,
  ) async {
    final service = ReportService();
    final auth = TestAuth();
    await pumpReport(tester, service, auth);
    await tester.tap(find.byKey(const Key('report-reason-SPAM')));
    await tester.enterText(
      find.byKey(const Key('report-detail')),
      'private draft',
    );
    await submit(tester);
    auth.switchTo('another');
    await tester.pumpAndSettle();
    service.pending.single.complete(
      ReportReceipt(id: 'old-account', receivedAt: DateTime(2026)),
    );
    await tester.pumpAndSettle();
    expect(find.text('신고가 접수됐어요'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('report-detail')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('report-submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('own post cannot be reported', (tester) async {
    final service = ReportService();
    final auth = TestAuth()..switchTo('author');
    await pumpReport(tester, service, auth);
    await tester.scrollUntilVisible(
      find.byKey(const Key('report-submit')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('report-submit')))
          .onPressed,
      isNull,
    );
    expect(service.requests, isEmpty);
  });
}
