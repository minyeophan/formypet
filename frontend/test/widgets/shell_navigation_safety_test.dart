import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/screens/my/my_settings_screen.dart';
import 'package:frontend/widgets/app_action_sheet.dart';
import 'package:frontend/widgets/main_scaffold.dart';
import 'package:frontend/widgets/record_inputs/record_edit_action_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/my/my_inquiry_screen_test.dart' show InquiryAuth;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<GoRouter> pumpShell(
    WidgetTester tester,
    Widget page, {
    InquiryAuth? auth,
  }) async {
    final router = GoRouter(
      initialLocation: '/my/profile',
      routes: [
        ShellRoute(
          builder: (_, _, child) => MainScaffold(child: child),
          routes: [
            GoRoute(path: '/my/profile', builder: (_, _) => page),
            for (final path in ['/home', '/community', '/my'])
              GoRoute(
                path: path,
                builder: (_, _) => Scaffold(body: Text('page:$path')),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((_) => auth ?? InquiryAuth())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('newer route supersedes a tab exit waiting for a frame', (
    tester,
  ) async {
    final router = await pumpShell(tester, const MyProfileScreen());
    await tester.tap(find.text('홈'));
    router.go('/community');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/community');
  });

  testWidgets('pending photo does not update a form that is exiting', (
    tester,
  ) async {
    final picker = Completer<XFile?>();
    final photo = _ObservedPhoto();
    await pumpShell(tester, MyProfileScreen(pickImage: () => picker.future));
    await tester.tap(find.byKey(const Key('my-profile-photo-picker')));
    await tester.tap(find.text('홈'));
    picker.complete(photo);
    await tester.pumpAndSettle();
    expect(photo.reads, 0);
  });

  for (final tab in ['홈', '커뮤니티', '마이']) {
    testWidgets(
      'dirty profile guards $tab tab, cancel preserves input, discard exits',
      (tester) async {
        final router = await pumpShell(tester, const MyProfileScreen());
        await tester.enterText(find.byType(TextField).first, 'draft');
        final tabFinder = find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text(tab),
        );
        await tester.tap(tabFinder);
        await tester.pumpAndSettle();
        expect(find.text('입력을 그만할까요?'), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/my/profile');
        await tester.tap(find.text('계속 입력'));
        await tester.pumpAndSettle();
        expect(find.text('draft'), findsOneWidget);
        await tester.tap(tabFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('나가기'));
        await tester.pumpAndSettle();
        expect(find.byType(MyProfileScreen), findsNothing);
        // Disposed profile guard must not intercept later tab changes.
        await tester.tap(find.text('홈'));
        await tester.pumpAndSettle();
        expect(find.text('page:/home'), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
      },
    );
  }

  testWidgets('saving profile blocks tab exit and failed save retains draft', (
    tester,
  ) async {
    final auth = _SavingAuth();
    final router = await pumpShell(tester, const MyProfileScreen(), auth: auth);
    await tester.enterText(find.byType(TextField).first, 'draft');
    await tester.tap(find.byKey(const Key('my-profile-save')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('홈'));
    await tester.pump(const Duration(seconds: 1));
    expect(router.routeInformationProvider.value.uri.path, '/my/profile');
    auth.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('draft'), findsOneWidget);
    expect(find.text('프로필을 저장하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
  });

  for (final kind in ['logout', 'delete', 'actions']) {
    testWidgets('$kind sheet blocks taps on shell bottom tabs', (tester) async {
      final page = Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              switch (kind) {
                case 'logout':
                  showLogoutConfirmationSheet(context);
                case 'delete':
                  showRecordDeleteConfirmationSheet(context);
                case 'actions':
                  showAppActionSheet(context, title: '더보기', actions: []);
              }
            },
            child: const Text('open'),
          ),
        ),
      );
      final router = await pumpShell(tester, page);
      final homePoint = tester.getCenter(find.text('홈'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(homePoint);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/my/profile');
      expect(find.text('page:/home'), findsNothing);
    });
  }
}

class _SavingAuth extends InquiryAuth {
  final pending = Completer<void>();
  @override
  Future<void> updateProfile({required String nickname}) => pending.future;
}

class _ObservedPhoto extends XFile {
  _ObservedPhoto() : super('test-only.png');
  int reads = 0;
  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return Uint8List(0);
  }
}
