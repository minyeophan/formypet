import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/my/my_inquiry_screen.dart';
import 'package:frontend/screens/my/inquiry_type_dropdown.dart';
import 'package:frontend/services/inquiry_service.dart';
import 'package:frontend/core/app_v2_tokens.dart';

class InquiryAuth extends AuthNotifier {
  InquiryAuth() : super.test(session('me'));
  static AuthState session(String id) => AuthState(
    isLoading: false,
    isAuthenticated: true,
    profile: UserProfile(id: id, email: '$id@example.com', nickname: id),
  );
  void switchTo(String id) => state = session(id);
  void signOut() =>
      state = const AuthState(isLoading: false, isAuthenticated: false);
}

class FakeInquiryService extends InquiryService {
  final drafts = <InquiryDraft>[];
  final ids = <String>[];
  final pending = <Completer<InquiryReceipt>>[];
  @override
  Future<InquiryReceipt> submit(
    InquiryDraft draft, {
    required String requestId,
  }) {
    drafts.add(draft);
    ids.add(requestId);
    final result = Completer<InquiryReceipt>();
    pending.add(result);
    return result.future;
  }
}

Future<void> pumpInquiry(
  WidgetTester tester,
  FakeInquiryService service, {
  InquiryAuth? auth,
  GoRouter? router,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((_) => auth ?? InquiryAuth()),
        inquiryServiceProvider.overrideWithValue(service),
      ],
      child: router == null
          ? const MaterialApp(home: MyInquiryScreen())
          : MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fillInquiry(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('inquiry-title')), '로그인 오류');
  await tester.enterText(
    find.byKey(const Key('my-inquiry-body-field')),
    '로그인 후 화면이 멈춥니다.',
  );
}

Future<void> sendInquiry(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('inquiry-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('type menu uses mint selection and matches field width', (
    tester,
  ) async {
    await pumpInquiry(tester, FakeInquiryService());
    final trigger = find.byKey(const Key('inquiry-type-trigger'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final item = find.byKey(const Key('inquiry-type-option-ACCOUNT'));
    expect(item, findsOneWidget);
    expect(find.text('✓'), findsOneWidget);
    expect(
      tester.widget<MenuItemButton>(item).style!.backgroundColor!.resolve({}),
      AppV2Tokens.mintSurface,
    );
    expect(
      tester.getTopLeft(item).dy,
      closeTo(tester.getBottomLeft(trigger).dy + 16, 1),
    );
    expect(
      tester.getSize(item).width,
      closeTo(tester.getSize(trigger).width - 16, 1),
    );
    await tester.tap(find.byKey(const Key('inquiry-type-option-BUG')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inquiry-type-option-BUG')), findsNothing);
    expect(find.text('오류 신고'), findsOneWidget);
  });
  testWidgets('type menu dismisses outside and after account change', (
    tester,
  ) async {
    final auth = InquiryAuth();
    await pumpInquiry(tester, FakeInquiryService(), auth: auth);
    await tester.tap(find.byKey(const Key('inquiry-type-trigger')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.tap(find.byKey(const Key('inquiry-type-trigger')));
    await tester.pumpAndSettle();
    auth.switchTo('another');
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('inquiry-type-trigger')))
          .onPressed,
      isNull,
    );
  });
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'validates blank fields and invalid reply email without sending',
    (tester) async {
      final service = FakeInquiryService();
      await pumpInquiry(tester, service);
      await tester.enterText(
        find.byKey(const Key('inquiry-email')),
        'bad-email',
      );
      await sendInquiry(tester);
      expect(find.text('올바른 이메일 주소를 입력해 주세요.'), findsOneWidget);
      expect(find.text('제목을 입력해 주세요.'), findsOneWidget);
      expect(find.text('문의 내용을 입력해 주세요.'), findsOneWidget);
      expect(service.ids, isEmpty);
      await tester.enterText(find.byKey(const Key('inquiry-email')), '   ');
      await sendInquiry(tester);
      expect(find.text('답변받을 이메일을 입력해 주세요.'), findsOneWidget);
    },
  );

  testWidgets(
    'failure preserves draft and same request retry; duplicate send blocked',
    (tester) async {
      final service = FakeInquiryService();
      await pumpInquiry(tester, service);
      await fillInquiry(tester);
      await tester.enterText(
        find.byKey(const Key('inquiry-email')),
        ' reply@example.com ',
      );
      await sendInquiry(tester);
      await sendInquiry(tester);
      expect(service.ids, hasLength(1));
      expect(service.drafts.single.replyEmail, 'reply@example.com');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('inquiry-title')))
            .enabled,
        isFalse,
      );
      service.pending.single.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('inquiry-title')))
            .controller!
            .text,
        '로그인 오류',
      );
      expect(find.text('문의가 접수됐어요'), findsNothing);
      await sendInquiry(tester);
      expect(service.ids.first, service.ids.last);
      service.pending.last.complete(
        InquiryReceipt(id: 'i1', receivedAt: DateTime(2026)),
      );
      await tester.pumpAndSettle();
      expect(find.text('문의가 접수됐어요'), findsOneWidget);
      expect(find.text('reply@example.com'), findsOneWidget);
      expect(find.byKey(const Key('inquiry-submit')), findsNothing);
    },
  );

  testWidgets('edited payload uses a new request id and selected type', (
    tester,
  ) async {
    final service = FakeInquiryService();
    await pumpInquiry(tester, service);
    await fillInquiry(tester);
    await sendInquiry(tester);
    service.pending.single.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(InquiryTypeDropdown));
    await tester.tap(find.byType(InquiryTypeDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오류 신고').last);
    await tester.pumpAndSettle();
    await sendInquiry(tester);
    expect(service.ids.first, isNot(service.ids.last));
    expect(service.drafts.last.type, 'BUG');
    service.pending.last.completeError(Exception('offline'));
    await tester.pumpAndSettle();
  });

  for (final logout in [false, true]) {
    testWidgets(
      '${logout ? 'logout' : 'account switch'} clears draft and ignores pending success',
      (tester) async {
        final auth = InquiryAuth();
        final service = FakeInquiryService();
        await pumpInquiry(tester, service, auth: auth);
        await fillInquiry(tester);
        await sendInquiry(tester);
        if (logout) {
          auth.signOut();
        } else {
          auth.switchTo('another');
        }
        await tester.pumpAndSettle();
        service.pending.single.complete(
          InquiryReceipt(id: 'old', receivedAt: DateTime(2026)),
        );
        await tester.pumpAndSettle();
        for (final key in [
          'inquiry-email',
          'inquiry-title',
          'my-inquiry-body-field',
        ]) {
          expect(
            tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text,
            isEmpty,
          );
        }
        expect(find.text('문의가 접수됐어요'), findsNothing);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('inquiry-submit')))
              .onPressed,
          isNull,
        );
      },
    );
  }

  testWidgets('anonymous user cannot compose or submit', (tester) async {
    final auth = InquiryAuth()..signOut();
    final service = FakeInquiryService();
    await pumpInquiry(tester, service, auth: auth);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('inquiry-submit')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('inquiry-email')))
          .enabled,
      isFalse,
    );
    expect(service.ids, isEmpty);
  });

  testWidgets(
    'submission blocks back navigation then completion returns to my page',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/my',
        routes: [
          GoRoute(
            path: '/my',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/my/inquiry'),
                child: const Text('문의 열기'),
              ),
            ),
          ),
          GoRoute(
            path: '/my/inquiry',
            builder: (_, _) => const MyInquiryScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final service = FakeInquiryService();
      await pumpInquiry(tester, service, router: router);
      await tester.tap(find.text('문의 열기'));
      await tester.pumpAndSettle();
      await fillInquiry(tester);
      await sendInquiry(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MyInquiryScreen), findsOneWidget);
      service.pending.single.complete(
        InquiryReceipt(id: 'i1', receivedAt: DateTime(2026)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inquiry-done')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/my');
      expect(find.byType(MyInquiryScreen), findsNothing);
    },
  );

  testWidgets(
    'small screen with keyboard keeps submission reachable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final service = FakeInquiryService();
      await pumpInquiry(tester, service);
      await fillInquiry(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('inquiry-submit')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await sendInquiry(tester);
      service.pending.single.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('inquiry-submit')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('접수하지 못했어요').hitTestable(), findsOneWidget);
    },
  );
  testWidgets('signed in user can compose inquiry with profile email', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (_) => AuthNotifier.test(
              const AuthState(
                isLoading: false,
                isAuthenticated: true,
                profile: UserProfile(
                  id: 'me',
                  email: 'me@example.com',
                  nickname: '집사',
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: MyInquiryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('문의하신 내용은 이메일로 답변드려요.'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(
      tester
          .widget<InquiryTypeDropdown>(find.byType(InquiryTypeDropdown))
          .onChanged,
      isNotNull,
    );
    expect(find.textContaining('준비중'), findsNothing);
  });
}
