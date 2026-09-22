import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/screens/my/my_inquiry_screen.dart';
import 'package:frontend/services/inquiry_service.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'my_inquiry_screen_test.dart' as inquiry;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final readingBytes in [false, true]) {
    for (final accountChange in [false, true]) {
      for (final fail in [false, true]) {
        testWidgets(
          'profile ignores late photo bytes=$readingBytes account=$accountChange error=$fail',
          (tester) async {
            final auth = _PendingProfileAuth();
            final picker = Completer<XFile?>();
            final bytes = Completer<Uint8List>();
            final file = _PendingPhoto(bytes.future);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [authProvider.overrideWith((_) => auth)],
                child: MaterialApp(
                  home: MyProfileScreen(pickImage: () => picker.future),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('my-profile-photo-picker')));
            if (readingBytes) {
              picker.complete(file);
              await tester.pump();
            }
            if (accountChange) {
              auth.switchTo('next');
              await tester.pumpAndSettle();
            } else {
              await tester.enterText(find.byType(TextField).first, 'new name');
              await tester.tap(find.byKey(const Key('my-profile-save')));
              await tester.pumpAndSettle();
              // Even after failure re-enables editing, the older picker is stale.
              auth.save.completeError(StateError('offline'));
              await tester.pumpAndSettle();
            }
            if (readingBytes) {
              if (fail) {
                bytes.completeError(StateError('late read'));
              } else {
                bytes.complete(Uint8List.fromList([1, 2, 3]));
              }
            } else {
              if (fail) {
                picker.completeError(StateError('late picker'));
              } else {
                bytes.complete(Uint8List.fromList([1, 2, 3]));
                picker.complete(file);
              }
            }
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('my-profile-local-preview')),
              findsNothing,
            );
            expect(find.text('사진을 불러오지 못했어요.'), findsNothing);
            if (!readingBytes && !fail) expect(file.reads, 0);
            expect(
              find.text(accountChange ? 'next' : 'new name'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  for (final profile in [false, true]) {
    for (final switchAccount in [false, true]) {
      testWidgets(
        'normalized draft and account reset profile=$profile switch=$switchAccount',
        (tester) async {
          final auth = inquiry.InquiryAuth();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith((_) => auth),
                inquiryServiceProvider.overrideWithValue(
                  inquiry.FakeInquiryService(),
                ),
              ],
              child: MaterialApp(
                home: profile
                    ? const MyProfileScreen()
                    : const MyInquiryScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final field = profile
              ? find.byType(TextField).first
              : find.byKey(const Key('inquiry-title'));
          await tester.enterText(field, 'draft');
          if (switchAccount) {
            auth.switchTo('next');
          } else {
            await tester.enterText(field, profile ? ' me ' : '  ');
          }
          await tester.pumpAndSettle();
          final guard = tester.widget<PopScope<Object?>>(
            find.byType(PopScope<Object?>),
          );
          expect(guard.canPop, isTrue);
          expect(find.text('draft'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'dirty ${profile ? 'profile' : 'inquiry'} asks before leaving',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/edit',
          routes: [
            GoRoute(
              path: '/edit',
              builder: (_, _) =>
                  profile ? const MyProfileScreen() : const MyInquiryScreen(),
            ),
            GoRoute(
              path: '/my',
              builder: (_, _) => const Scaffold(body: Text('home')),
            ),
            GoRoute(
              path: '/my/settings',
              builder: (_, _) => const Scaffold(body: Text('home')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((_) => inquiry.InquiryAuth()),
              inquiryServiceProvider.overrideWithValue(
                inquiry.FakeInquiryService(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          profile
              ? find.byType(TextField).first
              : find.byKey(const Key('inquiry-title')),
          'draft',
        );
        tester.widget<AppHeader>(find.byType(AppHeader)).onBack!();
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        await tester.tap(find.text('계속 입력'));
        await tester.pumpAndSettle();
        expect(find.text('draft'), findsOneWidget);
        tester.widget<AppHeader>(find.byType(AppHeader)).onBack!();
        await tester.pumpAndSettle();
        await tester.tap(find.text('나가기'));
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
      },
    );
  }
}

class _PendingProfileAuth extends inquiry.InquiryAuth {
  final save = Completer<void>();
  @override
  Future<void> updateProfile({required String nickname}) => save.future;
}

class _PendingPhoto extends XFile {
  _PendingPhoto(this.bytes) : super('fake-photo.png');
  final Future<Uint8List> bytes;
  int reads = 0;
  @override
  Future<Uint8List> readAsBytes() {
    reads++;
    return bytes;
  }
}
