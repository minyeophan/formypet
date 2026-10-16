// Synthetic fixtures on local QA only. Preserve package data with --no-uninstall.
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
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('support inquiry and report receipts survive retries and restart', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    final directory = (await getExternalStorageDirectory())!;
    expect(directory.path, contains('com.formypet.frontend.mediatest/'));
    initApiClient('http://127.0.0.1:18083');
    final fixture = File('${directory.path}/support-migration.json');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_SUPPORT');
    Map<String, dynamic> saved;
    Dio? author;
    if (existing) {
      saved = jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
      expect((await AuthService().getProfile()).id, saved['userId']);
      await _sameReceipt(
        '/api/v1/inquiries',
        saved['inquiry'],
        saved['inquiryReceipt'],
      );
      // The target was deleted in the full run; accepted report retries still work.
      await _sameReceipt(
        '/api/v1/posts/${saved['postId']}/reports',
        saved['report'],
        saved['reportReceipt'],
      );
    } else {
      final owner = await AuthService().register(
        email:
            'support-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
        password: _password(),
        nickname: 'JPA 문의 검증',
      );
      await PetService().createPet({'name': '문의 검증', 'species': 'dog'});
      saved = {'userId': owner.id};
      author = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:18083'));
      addTearDown(author.close);
      final tokens =
          unwrap(
                await author.post(
                  '/api/v1/auth/register',
                  data: {
                    'email':
                        'support-author-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
                    'password': _password(),
                    'nickname': '문의 검증 작성자',
                  },
                ),
              )
              as Map<String, dynamic>;
      author.options.headers['Authorization'] =
          'Bearer ${tokens['accessToken']}';
      final post =
          unwrap(
                await author.post(
                  '/api/v1/posts',
                  data: FormData.fromMap({
                    'payload': jsonEncode({
                      'title': 'JPA 신고 대상',
                      'content': '격리 QA 신고 본문',
                      'category': 'FREE',
                    }),
                  }),
                ),
              )
              as Map<String, dynamic>;
      saved['postId'] = post['id'].toString();
    }

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
    router.go('/my/inquiry');
    await _until(
      tester,
      () => find.byKey(const Key('inquiry-title')).evaluate().isNotEmpty,
    );
    if (!existing) {
      final attempts = <Map<String, dynamic>>[];
      var failOnce = true;
      final capture = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST' && options.path == '/api/v1/inquiries') {
            final payload = Map<String, dynamic>.from(options.data as Map);
            attempts.add(payload);
            saved['inquiry'] = payload;
            if (failOnce) {
              failOnce = false;
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: 'Synthetic isolated QA transport failure',
                ),
              );
              return;
            }
          }
          if (options.method == 'POST' && options.path.endsWith('/reports')) {
            saved['report'] = Map<String, dynamic>.from(options.data as Map);
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.requestOptions.path == '/api/v1/inquiries') {
            saved['inquiryReceipt'] = Map<String, dynamic>.from(
              unwrap(response) as Map,
            );
          }
          if (response.requestOptions.path.endsWith('/reports')) {
            saved['reportReceipt'] = Map<String, dynamic>.from(
              unwrap(response) as Map,
            );
          }
          handler.next(response);
        },
      );
      dio.interceptors.add(capture);
      addTearDown(() => dio.interceptors.remove(capture));
      await _tap(tester, find.byKey(const Key('inquiry-submit')));
      expect(attempts, isEmpty);
      expect(find.text('제목을 입력해 주세요.'), findsOneWidget);
      await _fill(tester, 'inquiry-email', 'reply-support@example.invalid');
      await _fill(tester, 'inquiry-title', 'JPA 문의 제목');
      await _fill(tester, 'my-inquiry-body-field', 'JPA 문의 본문');
      await _tap(tester, find.byKey(const Key('inquiry-submit')));
      await _until(tester, () => find.text('접수하지 못했어요').evaluate().isNotEmpty);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('inquiry-title')))
            .controller!
            .text,
        'JPA 문의 제목',
      );
      await _tap(tester, find.byKey(const Key('inquiry-submit')));
      await _until(tester, () => find.text('문의가 접수됐어요').evaluate().isNotEmpty);
      expect(attempts, hasLength(2));
      expect(attempts[0], attempts[1]);
      _recentReceipt(saved['inquiryReceipt']);
      await _tap(tester, find.byKey(const Key('inquiry-done')));

      router.go('/community/posts/${saved['postId']}');
      await _tap(tester, find.byKey(const Key('community-detail-more-button')));
      await _tap(tester, find.byKey(const Key('community-post-report')));
      await _until(tester, () => find.text('게시글 신고').evaluate().isNotEmpty);
      await _scrollReport(tester, 'report-submit', 200);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('report-submit')))
            .onPressed,
        isNull,
      );
      await _scrollReport(tester, 'report-reason-OTHER', -200);
      await _tap(tester, find.byKey(const Key('report-reason-OTHER')));
      await _scrollReport(tester, 'report-submit', 200);
      await _tap(tester, find.byKey(const Key('report-submit')));
      expect(find.text('기타 사유의 상세 내용을 입력해 주세요.'), findsOneWidget);
      await _fill(tester, 'report-detail', 'JPA 신고 상세 내용');
      await _tap(tester, find.byKey(const Key('report-submit')));
      await _until(tester, () => find.text('신고가 접수됐어요').evaluate().isNotEmpty);
      _recentReceipt(saved['reportReceipt']);
      expect(
        find.text('접수번호 ${(saved['reportReceipt'] as Map)['id']}'),
        findsOneWidget,
      );
      dio.interceptors.remove(capture);
      await _sameReceipt(
        '/api/v1/inquiries',
        saved['inquiry'],
        saved['inquiryReceipt'],
      );
      final reportPath = '/api/v1/posts/${saved['postId']}/reports';
      await _sameReceipt(reportPath, saved['report'], saved['reportReceipt']);
      await _expectStatus(
        dio.post(
          '/api/v1/inquiries',
          data: {
            ...Map<String, dynamic>.from(saved['inquiry'] as Map),
            'body': '다른 본문',
          },
        ),
        409,
      );
      await _expectStatus(
        dio.post(
          reportPath,
          data: {
            ...Map<String, dynamic>.from(saved['report'] as Map),
            'requestId': 'different-request',
          },
        ),
        409,
      );
      await _expectStatus(
        dio.post(
          '/api/v1/inquiries',
          data: {
            ...Map<String, dynamic>.from(saved['inquiry'] as Map),
            'title': 'bad\nheader',
            'requestId': 'invalid-header',
          },
        ),
        400,
      );
      await _tap(tester, find.text('게시글로 돌아가기'));
      router.go('/my');
      await tester.pumpAndSettle();
      await author!.delete('/api/v1/posts/${saved['postId']}');
      await _sameReceipt(reportPath, saved['report'], saved['reportReceipt']);
      await fixture.writeAsString(jsonEncode(saved));
    } else {
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('inquiry-title')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('1대1 문의하기'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'SUPPORT_RESTART_VERIFIED' : 'SUPPORT_FULL_VERIFIED');
  });
}

Future<void> _sameReceipt(
  String path,
  dynamic payload,
  dynamic expected,
) async {
  expect(unwrap(await dio.post(path, data: payload)), expected);
}

void _recentReceipt(dynamic receipt) {
  final data = receipt as Map;
  expect(data['id'], isA<String>());
  final at = DateTime.parse(data['receivedAt'] as String);
  expect(at.isUtc, isTrue);
  expect(
    DateTime.now().toUtc().difference(at).abs(),
    lessThan(const Duration(minutes: 1)),
  );
}

Future<void> _expectStatus(
  Future<Response<dynamic>> request,
  int status,
) async {
  await expectLater(
    request,
    throwsA(
      isA<DioException>().having(
        (e) => e.response?.statusCode,
        'HTTP status',
        status,
      ),
    ),
  );
}

String _password() => List.generate(
  32,
  (_) => Random.secure().nextInt(16).toRadixString(16),
).join();
Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Support UI did not become ready');
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

Future<void> _fill(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(Key(key));
  await _until(tester, () => finder.evaluate().isNotEmpty);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.enterText(finder, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}

Future<void> _scrollReport(
  WidgetTester tester,
  String key,
  double delta,
) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    delta,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}
