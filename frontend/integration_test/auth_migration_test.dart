// Real isolated QA API and app widgets; synthetic accounts only.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('authentication rotation logout login recovery and restart', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    final directory = (await getExternalStorageDirectory())!;
    expect(directory.path, contains('com.formypet.frontend.mediatest/'));
    initApiClient('http://127.0.0.1:18083');
    final fixture = File('${directory.path}/auth-migration.json');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_AUTH');
    final auth = AuthService();
    final password = List.generate(
      32,
      (_) => Random.secure().nextInt(16).toRadixString(16),
    ).join();
    Map<String, dynamic> saved;
    if (existing) {
      saved = jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
    } else {
      final email =
          'auth-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
      final user = await auth.register(
        email: email,
        password: password,
        nickname: 'JPA 인증',
      );
      await PetService().createPet({'name': '인증 검증', 'species': 'dog'});
      saved = {'userId': user.id, 'email': email};
    }
    expect((await auth.getProfile()).id, saved['userId']);
    final raw = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:18083'));
    addTearDown(raw.close);
    // A rejected access token exercises the real client refresh interceptor.
    final previousRefresh = (await getRefreshToken())!;
    await saveAccessToken('invalid-access-for-isolated-qa');
    expect((await auth.getProfile()).id, saved['userId']);
    expect(await getRefreshToken(), isNot(previousRefresh));
    await _status(
      raw.post('/api/v1/auth/refresh', data: {'refreshToken': previousRefresh}),
      401,
    );

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
          container.read(authProvider).isAuthenticated &&
          !container.read(petProvider).isLoading &&
          container.read(petProvider).hasOnboarded,
    );
    expect(container.read(authProvider).profile!.id, saved['userId']);
    if (!existing) {
      final logoutRefresh = (await getRefreshToken())!;
      container.read(routerProvider).go('/my/settings');
      await _tap(tester, find.text('로그아웃'));
      await _tap(tester, find.byKey(const Key('logout-confirm-button')));
      await _until(
        tester,
        () =>
            !container.read(authProvider).isLoading &&
            !container.read(authProvider).isAuthenticated,
      );
      expect(await getAccessToken(), isNull);
      expect(await getRefreshToken(), isNull);
      await _status(
        raw.post('/api/v1/auth/refresh', data: {'refreshToken': logoutRefresh}),
        401,
      );
      await _tap(tester, find.text('이메일로 로그인'));
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        saved['email'] as String,
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'DefinitelyWrong123!',
      );
      await _tap(tester, find.byKey(const Key('auth-submit-button')));
      await _until(
        tester,
        () => find.text('이메일 또는 비밀번호를 확인해 주세요.').evaluate().isNotEmpty,
      );
      expect(container.read(authProvider).isAuthenticated, isFalse);

      await _tap(tester, find.byKey(const Key('auth-password-recovery')));
      await tester.enterText(
        find.byKey(const Key('recovery-email')),
        saved['email'] as String,
      );
      await _tap(tester, find.byKey(const Key('recovery-submit')));
      await _until(
        tester,
        () => find
            .text('현재 비밀번호 복구를 이용할 수 없어요. 잠시 후 다시 시도해 주세요.')
            .evaluate()
            .isNotEmpty,
      );
      await _tap(tester, find.byTooltip('로그인으로 돌아가기'));
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        saved['email'] as String,
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        password,
      );
      await _tap(tester, find.byKey(const Key('auth-submit-button')));
      await _until(
        tester,
        () =>
            !container.read(authProvider).isLoading &&
            container.read(authProvider).isAuthenticated,
      );
      expect(container.read(authProvider).profile!.id, saved['userId']);
      await fixture.writeAsString(jsonEncode(saved));
    }
    expect((await auth.getProfile()).id, saved['userId']);
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'AUTH_RESTART_VERIFIED' : 'AUTH_FULL_VERIFIED');
  });
}

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
  fail('Auth UI did not become ready');
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
