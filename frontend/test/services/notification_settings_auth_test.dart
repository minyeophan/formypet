import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/secure_storage.dart';
import 'package:frontend/services/notification_service.dart';
import '../support/audit_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initApiClient('https://example.test'));
  test(
    'real auth interceptor rejects account replacement after settings snapshot',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      await saveTokens(access: 'account-a', refresh: 'refresh-a');
      final queued = Completer<void>();
      final release = Completer<void>();
      final gate = InterceptorsWrapper(
        onRequest: (options, handler) async {
          queued.complete();
          await release.future;
          handler.next(options);
        },
      );
      dio.interceptors.insert(0, gate);
      addTearDown(() => dio.interceptors.remove(gate));
      final api = AuditApi((r) => {'enabled': false});
      useAuditApi(api);
      final pending = NotificationService().updateSettings(false);
      await queued.future;
      await saveTokens(access: 'account-b', refresh: 'refresh-b');
      release.complete();
      await expectLater(
        pending,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(api.requests, isEmpty);
    },
  );
}
