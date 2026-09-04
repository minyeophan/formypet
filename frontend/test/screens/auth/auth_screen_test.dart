import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/auth/auth_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('kakao failure stays visible on welcome and allows retry', (
    tester,
  ) async {
    final service = _FakeAuthService()
      ..kakaoError = Exception('internal SDK detail');
    await _pumpAuth(tester, service: service);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('internal SDK detail'), findsNothing);
    expect(find.text('이메일로 로그인'), findsOneWidget);
  });

  testWidgets(
    'registration validates nickname and short password then submits own account',
    (tester) async {
      final service = _FakeAuthService();
      await _pumpAuth(tester, service: service);
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-nickname-field')),
        '가' * 51,
      );
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        ' pet@example.com ',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'short',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-submit-button')));
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(find.text('닉네임은 50자 이하로 입력해 주세요.'), findsOneWidget);
      expect(service.registerCalls, 0);
      await tester.enterText(
        find.byKey(const Key('auth-nickname-field')),
        ' 집사 ',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'password123',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-submit-button')));
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(service.registerCalls, 1);
      expect(service.registeredEmail, 'pet@example.com');
      expect(service.registeredNickname, '집사');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuthScreen)),
      );
      expect(container.read(authProvider).isAuthenticated, isTrue);
    },
  );

  testWidgets('system back returns to welcome instead of leaving auth', (
    tester,
  ) async {
    await _pumpAuth(tester);
    await _openLogin(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });

  testWidgets('network failure retains password and clears on correction', (
    tester,
  ) async {
    final service = _FakeAuthService()
      ..loginError = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      );
    await _pumpAuth(tester, service: service);
    await _openLogin(tester);
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'pet@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'legacy',
    );
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
    expect(_passwordField(tester).controller!.text, 'legacy');
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'retry',
    );
    await tester.pump();
    expect(find.text('네트워크 연결을 확인해 주세요.'), findsNothing);
  });

  testWidgets(
    'welcome opens email login, registration, and returns to welcome',
    (tester) async {
      await _pumpAuth(tester);

      expect(find.text('카카오로 시작하기'), findsOneWidget);
      expect(find.text('이메일로 로그인'), findsOneWidget);
      expect(find.text('회원가입'), findsOneWidget);
      final emailButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('이메일로 로그인'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(
        emailButton.style?.side?.resolve({}),
        const BorderSide(color: Color(0xFF151C27), width: 1.2),
      );
      expect(
        tester.widget<Text>(find.text('회원가입')).style?.color,
        const Color(0xFF151C27),
      );

      await tester.tap(find.text('이메일로 로그인'));
      await tester.pumpAndSettle();
      expect(find.text('로그인'), findsAtLeastNWidgets(2));
      expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find.byKey(const Key('auth-submit-button')),
      );
      expect(
        submit.style?.backgroundColor?.resolve({}),
        const Color(0xFF32B982),
      );

      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      expect(find.text('회원가입'), findsAtLeastNWidgets(2));
      expect(find.byKey(const Key('auth-nickname-field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('카카오로 시작하기'), findsOneWidget);
    },
  );

  testWidgets('invalid email blocks login before an auth request', (
    tester,
  ) async {
    final service = _FakeAuthService();
    await _pumpAuth(tester, service: service);

    await tester.tap(find.text('이메일로 로그인'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'legacy',
    );
    await tester.tap(find.text('로그인').last);
    await tester.pump();

    expect(find.text('이메일을 확인해 주세요.'), findsOneWidget);
    expect(service.loginCalls, 0);
  });

  testWidgets(
    'server password constraint is explained without technical text',
    (tester) async {
      final service = _FakeAuthService()
        ..loginError = ApiException(
          statusCode: 400,
          title: 'Validation failed',
          fieldErrors: {'password': 'size must be between 8 and 2147483647'},
        );
      await _pumpAuth(tester, service: service);
      await _openLogin(tester);
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'pet@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'legacy',
      );
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(find.text('비밀번호는 8자 이상 입력해 주세요.'), findsOneWidget);
      expect(find.textContaining('2147483647'), findsNothing);
    },
  );

  testWidgets('backend email field failure is friendly and retains input', (
    tester,
  ) async {
    final service = _FakeAuthService()
      ..loginError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        error: ApiException(
          statusCode: 409,
          title: 'Duplicate email internal detail',
          fieldErrors: {'email': 'duplicate_email'},
        ),
      );
    await _pumpAuth(tester, service: service);
    await _openLogin(tester);
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'pet@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'legacy',
    );
    await tester.tap(find.text('로그인').last);
    await tester.pumpAndSettle();

    expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
    expect(find.text('Duplicate email internal detail'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('auth-email-field')))
          .controller!
          .text,
      'pet@example.com',
    );
  });

  testWidgets(
    'password visibility control reveals and hides entered password',
    (tester) async {
      await _pumpAuth(tester);
      await _openLogin(tester);

      expect(_passwordField(tester).obscureText, isTrue);
      await tester.tap(find.byKey(const Key('auth-password-visibility')));
      await tester.pump();
      expect(_passwordField(tester).obscureText, isFalse);
    },
  );

  testWidgets('pending login sends one request and survives disposal', (
    tester,
  ) async {
    final service = _FakeAuthService()..pendingLogin = Completer<UserProfile>();
    await _pumpAuth(tester, service: service);
    await _openLogin(tester);
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'pet@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'legacy',
    );
    await tester.tap(find.text('로그인').last);
    await tester.pump();
    await tester.tap(find.text('로그인').last);
    await tester.pump();
    expect(service.loginCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    service.pendingLogin!.complete(_profile);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'register form remains usable with compact viewport, keyboard, and text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpAuth(tester);
      await tester.ensureVisible(find.text('회원가입'));
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth-password-field')));
      await tester.pump();

      expect(find.byKey(const Key('auth-submit-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpAuth(WidgetTester tester, {AuthService? service}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.test(
            const AuthState(isLoading: false, isAuthenticated: false),
            service: service,
          ),
        ),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const AuthScreen()),
    ),
  );
}

Future<void> _openLogin(WidgetTester tester) async {
  await tester.tap(find.text('이메일로 로그인'));
  await tester.pumpAndSettle();
}

TextField _passwordField(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('auth-password-field')));

class _FakeAuthService extends AuthService {
  int loginCalls = 0;
  int registerCalls = 0;
  String? registeredEmail;
  String? registeredNickname;
  Object? kakaoError;
  Object? loginError;
  Completer<UserProfile>? pendingLogin;

  @override
  Future<UserProfile?> loginWithKakao() async {
    if (kakaoError != null) throw kakaoError!;
    return null;
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    registerCalls++;
    registeredEmail = email;
    registeredNickname = nickname;
    return _profile;
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    if (pendingLogin != null) return pendingLogin!.future;
    return _profile;
  }
}

const _profile = UserProfile(
  id: 'user-1',
  email: 'test@example.com',
  nickname: '테스트',
);
