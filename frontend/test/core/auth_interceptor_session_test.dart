import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/secure_storage.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initApiClient('https://example.test'));
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await saveTokens(access: 'account-a', refresh: 'refresh-a');
  });
  tearDown(() => setAuthExpiredHandler(null));

  test(
    'late 401 cannot refresh or clear the next account credentials',
    () async {
      final response = Completer<ResponseBody>();
      final started = Completer<void>();
      var refreshes = 0;
      var expired = 0;
      setAuthExpiredHandler(() async => expired++);
      dio.httpClientAdapter = _Adapter((request) {
        if (request.path.contains('/auth/refresh')) {
          refreshes++;
          return _tokens('unexpected');
        }
        if (!started.isCompleted) {
          started.complete();
          return response.future;
        }
        return _body(200);
      });
      final pending = dio.get('/private');
      final rejected = expectLater(pending, throwsA(isA<DioException>()));
      await started.future;
      await saveTokens(access: 'account-b', refresh: 'refresh-b');
      response.complete(_body(401));
      await rejected;
      expect(refreshes, 0);
      expect(expired, 0);
      expect(await getAccessToken(), 'account-b');
      expect(await getRefreshToken(), 'refresh-b');
    },
  );

  test('late refresh success cannot overwrite the next account', () async {
    final refresh = Completer<ResponseBody>();
    final started = Completer<void>();
    dio.httpClientAdapter = _Adapter((request) {
      if (request.path.contains('/auth/refresh')) {
        started.complete();
        return refresh.future;
      }
      return _body(
        request.headers['Authorization'] == 'Bearer account-a' ? 401 : 200,
      );
    });
    final pending = dio.get('/private');
    final rejected = expectLater(pending, throwsA(isA<DioException>()));
    await started.future;
    await saveTokens(access: 'account-b', refresh: 'refresh-b');
    refresh.complete(_tokens('renewed-a'));
    await rejected;
    expect(await getAccessToken(), 'account-b');
    expect(await getRefreshToken(), 'refresh-b');
  });

  test(
    'current account refresh succeeds and retries with the renewed token',
    () async {
      var refreshes = 0;
      final authorizations = <Object?>[];
      dio.httpClientAdapter = _Adapter((request) {
        if (request.path.contains('/auth/refresh')) {
          refreshes++;
          return _tokens('renewed-a');
        }
        authorizations.add(request.headers['Authorization']);
        return _body(
          request.headers['Authorization'] == 'Bearer account-a' ? 401 : 200,
        );
      });
      expect((await dio.get('/private')).statusCode, 200);
      expect(refreshes, 1);
      expect(authorizations, ['Bearer account-a', 'Bearer renewed-a']);
      expect(await getAccessToken(), 'renewed-a');
    },
  );

  for (final switched in [false, true]) {
    test(
      'refresh failure completes and only expires its own session switched=$switched',
      () async {
        final refresh = Completer<ResponseBody>();
        final started = Completer<void>();
        var expired = 0;
        setAuthExpiredHandler(() async => expired++);
        dio.httpClientAdapter = _Adapter((request) {
          if (request.path.contains('/auth/refresh')) {
            started.complete();
            return refresh.future;
          }
          return _body(401);
        });
        final pending = dio.get('/private');
        final rejected = expectLater(
          pending.timeout(const Duration(seconds: 2)),
          throwsA(isA<DioException>()),
        );
        await started.future;
        if (switched) {
          await saveTokens(access: 'account-b', refresh: 'refresh-b');
        }
        refresh.complete(_body(401));
        await rejected;
        expect(expired, switched ? 0 : 1);
        expect(await getAccessToken(), switched ? 'account-b' : isNull);
      },
    );
  }

  test(
    'concurrent 401 responses share a refresh and all requests finish',
    () async {
      var refreshes = 0;
      var originalRequests = 0;
      final allStarted = Completer<void>();
      dio.httpClientAdapter = _Adapter((request) async {
        if (request.path.contains('/auth/refresh')) {
          refreshes++;
          return _tokens('renewed-a');
        }
        if (request.headers['Authorization'] == 'Bearer account-a') {
          originalRequests++;
          if (originalRequests == 3) allStarted.complete();
          await allStarted.future;
          return _body(401);
        }
        return _body(200);
      });
      final responses = await Future.wait([
        dio.get('/one'),
        dio.get('/two'),
        dio.get('/three'),
      ]).timeout(const Duration(seconds: 2));
      expect(responses.map((r) => r.statusCode), [200, 200, 200]);
      expect(refreshes, 1);
    },
  );

  test(
    'transient retry does not replay a private GET under another account',
    () async {
      final response = Completer<ResponseBody>();
      final started = Completer<void>();
      final authorizations = <Object?>[];
      dio.httpClientAdapter = _Adapter((request) {
        authorizations.add(request.headers['Authorization']);
        if (!started.isCompleted) {
          started.complete();
          return response.future;
        }
        return _body(200);
      });
      final pending = dio.get('/private');
      final rejected = expectLater(pending, throwsA(isA<DioException>()));
      await started.future;
      await saveTokens(access: 'account-b', refresh: 'refresh-b');
      response.complete(_body(503));
      await rejected;
      expect(authorizations, ['Bearer account-a']);
      expect(await getAccessToken(), 'account-b');
    },
  );

  test(
    'a rejected retried request neither loops nor clears renewed credentials',
    () async {
      var refreshes = 0;
      dio.httpClientAdapter = _Adapter((request) {
        if (request.path.contains('/auth/refresh')) {
          refreshes++;
          return _tokens('renewed-a');
        }
        return _body(401);
      });
      await expectLater(
        dio.get('/private').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>()),
      );
      expect(refreshes, 1);
      expect(await getAccessToken(), 'renewed-a');
    },
  );
  test('temporary refresh outage retains login and can be retried', () async {
    var refreshes = 0;
    var expired = 0;
    setAuthExpiredHandler(() async => expired++);
    dio.httpClientAdapter = _Adapter((request) {
      if (request.path.contains('/auth/refresh')) {
        refreshes++;
        return refreshes == 1 ? _body(503) : _tokens('renewed-a');
      }
      return _body(
        request.headers['Authorization'] == 'Bearer account-a' ? 401 : 200,
      );
    });
    await expectLater(dio.get('/private'), throwsA(isA<DioException>()));
    expect(await getAccessToken(), 'account-a');
    expect(expired, 0);
    expect((await dio.get('/private')).statusCode, 200);
    expect(refreshes, 2);
  });
  test('startup signs out when refresh credentials are rejected', () async {
    dio.httpClientAdapter = _Adapter((request) => _body(401));
    final settled = Completer<void>();
    final notifier = AuthNotifier(AuthService());
    final remove = notifier.addListener((state) {
      if (!state.isLoading && !settled.isCompleted) settled.complete();
    });
    addTearDown(() {
      remove();
      notifier.dispose();
    });
    await settled.future.timeout(const Duration(seconds: 2));
    expect(await getAccessToken(), isNull);
    expect(await getRefreshToken(), isNull);
    expect(notifier.state.isAuthenticated, isFalse);
    expect(notifier.state.initializationError, isNull);
  });

  test(
    'startup preserves credentials through a refresh service outage',
    () async {
      dio.httpClientAdapter = _Adapter(
        (request) => _body(request.path.contains('/auth/refresh') ? 503 : 401),
      );
      final settled = Completer<void>();
      final notifier = AuthNotifier(AuthService());
      final remove = notifier.addListener((state) {
        if (!state.isLoading && !settled.isCompleted) settled.complete();
      });
      addTearDown(() {
        remove();
        notifier.dispose();
      });
      await settled.future.timeout(const Duration(seconds: 2));
      expect(await getAccessToken(), 'account-a');
      expect(await getRefreshToken(), 'refresh-a');
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.initializationError, isNotNull);
      dio.httpClientAdapter = _Adapter((request) {
        if (request.path.contains('/auth/refresh')) return _tokens('renewed-a');
        return request.headers['Authorization'] == 'Bearer account-a'
            ? _body(401)
            : _body(200, {
                'data': {'id': 1, 'email': 'a@example.test', 'nickname': 'A'},
              });
      });
      await notifier.retryInitialization();
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.initializationError, isNull);
    },
  );
}

ResponseBody _tokens(String access) => _body(200, {
  'data': {'accessToken': access, 'refreshToken': 'refresh-$access'},
});

ResponseBody _body(int status, [Object body = const {}]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _Adapter implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  _Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}
