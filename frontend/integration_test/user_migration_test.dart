// Real local QA API and application widgets; synthetic accounts only.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/secure_storage.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/my/my_profile_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/community_safety_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/widgets/user_block_sheet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('user profile blocks and deletion preserve contracts', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    final directory = (await getExternalStorageDirectory())!;
    expect(directory.path, contains('com.formypet.frontend.mediatest/'));
    initApiClient('http://127.0.0.1:18083');
    final fixture = File('${directory.path}/user-migration.json');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_USER');
    final auth = AuthService();
    final safety = CommunitySafetyService();
    Map<String, dynamic> saved;
    if (existing) {
      saved = jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
    } else {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final owner = await auth.register(
        email: 'user-$stamp@example.invalid',
        password: _password(),
        nickname: 'JPA 회원',
      );
      await PetService().createPet({'name': '회원 검증', 'species': 'dog'});
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(40, 30);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      final first = await auth.uploadProfileImage(
        bytes: bytes,
        filename: 'user-first.png',
      );
      final second = await auth.uploadProfileImage(
        bytes: bytes,
        filename: 'user-second.png',
      );
      expect(second.profileImageUrl, isNot(first.profileImageUrl));
      final other = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:18083'));
      addTearDown(other.close);
      final tokens =
          unwrap(
                await other.post(
                  '/api/v1/auth/register',
                  data: {
                    'email': 'blocked-$stamp@example.invalid',
                    'password': _password(),
                    'nickname': '차단 검증 대상',
                  },
                ),
              )
              as Map;
      other.options.headers['Authorization'] =
          'Bearer ${tokens['accessToken']}';
      final target = unwrap(await other.get('/api/v1/users/me')) as Map;
      saved = {
        'userId': owner.id,
        'image': second.profileImageUrl,
        'targetId': target['id'].toString(),
        'nickname': 'JPA 회원 수정',
      };
    }
    expect((await auth.getProfile()).id, saved['userId']);
    expect((await auth.getProfile()).profileImageUrl, saved['image']);
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
    router.go('/my/profile');
    await _until(
      tester,
      () => find.byType(MyProfileScreen).evaluate().isNotEmpty,
    );
    if (!existing) {
      await tester.enterText(
        find.byType(TextField).first,
        '  ${saved['nickname']}  ',
      );
      await _tap(tester, find.byKey(const Key('my-profile-save')));
      await _until(
        tester,
        () =>
            container.read(authProvider).profile?.nickname == saved['nickname'],
      );
      router.go('/my/profile');
      await _until(
        tester,
        () => find.byType(MyProfileScreen).evaluate().isNotEmpty,
      );
      final pending = showUserBlockSheet(
        tester.element(find.byType(MyProfileScreen)),
        user: BlockedUser(
          userId: saved['targetId'] as String,
          nickname: '차단 검증 대상',
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, '차단'));
      expect(await pending, isTrue);
      await safety.block(
        saved['targetId'] as String,
      ); // duplicate is idempotent
    }
    expect((await auth.getProfile()).nickname, saved['nickname']);
    expect((await safety.getBlockedUsers()).map((e) => e.userId), [
      saved['targetId'],
    ]);
    router.go('/my/blocked-users');
    await _until(
      tester,
      () => find
          .byKey(Key('blocked-user-${saved['targetId']}'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text('차단 검증 대상'), findsOneWidget);
    if (!existing) {
      await _tap(tester, find.text('차단 해제'));
      await _tap(tester, find.widgetWithText(FilledButton, '차단 해제'));
      await _until(
        tester,
        () => find.text('차단한 사용자가 없어요.').evaluate().isNotEmpty,
      );
      expect(await safety.getBlockedUsers(), isEmpty);
      await safety.block(
        saved['targetId'] as String,
      ); // leave persistent fixture
      final original = await readCredentials();
      final password = _password();
      await container
          .read(authProvider.notifier)
          .register(
            email:
                'delete-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
            password: password,
            nickname: '탈퇴 검증',
          );
      final deletedAccess = await getAccessToken();
      final deletedRefresh = await getRefreshToken();
      final raw = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:18083',
          headers: {'Authorization': 'Bearer $deletedAccess'},
        ),
      );
      addTearDown(raw.close);
      await _status(
        raw.delete('/api/v1/users/me', data: {'password': 'wrong-password'}),
        401,
      );
      expect((await raw.get('/api/v1/users/me')).statusCode, 200);
      await PetService().createPet({'name': '탈퇴 검증', 'species': 'dog'});
      await container.read(petProvider.notifier).loadForAuthenticatedUser();
      expect(container.read(petProvider).hasOnboarded, isTrue);
      router.go('/my/settings/delete-account');
      await _until(tester, () => find.text('현재 비밀번호').evaluate().isNotEmpty);
      await tester.enterText(find.byType(TextField).first, password);
      await _tap(tester, find.widgetWithText(FilledButton, '계정 탈퇴'));
      await _tap(
        tester,
        find.byKey(const Key('account-delete-confirm-button')),
      );
      await _until(
        tester,
        () =>
            !container.read(authProvider).isAuthenticated &&
            !container.read(authProvider).isLoading,
      );
      expect(await getAccessToken(), isNull);
      await _status(raw.get('/api/v1/users/me'), 401);
      await _status(
        raw.post(
          '/api/v1/auth/refresh',
          data: {'refreshToken': deletedRefresh},
        ),
        401,
      );
      await saveTokens(access: original.access!, refresh: original.refresh!);
      await container.read(authProvider.notifier).retryInitialization();
      await _until(tester, () => container.read(authProvider).isAuthenticated);
      expect((await auth.getProfile()).id, saved['userId']);
      await fixture.writeAsString(jsonEncode(saved));
    }
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'USER_RESTART_VERIFIED' : 'USER_FULL_VERIFIED');
  });
}

String _password() => List.generate(
  32,
  (_) => Random.secure().nextInt(16).toRadixString(16),
).join();
Future<void> _status(Future<Response<dynamic>> request, int status) =>
    expectLater(
      request,
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'HTTP status',
          status,
        ),
      ),
    );
Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('User UI did not become ready');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: .5);
  await tester.pumpAndSettle();
  expect(finder.first.hitTestable(), findsOneWidget);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
