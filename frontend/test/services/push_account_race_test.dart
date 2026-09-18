import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/secure_storage.dart';
import 'package:frontend/services/push_notification_service.dart';
import '../support/audit_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = PushNotificationService.instance;
  const channel = MethodChannel('plugins.flutter.io/firebase_messaging');
  late Future<String> Function() token;
  setUpAll(() async {
    initApiClient('https://example.test');
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterSecureStorage.setMockInitialValues({});
    await saveTokens(access: 'account-a', refresh: 'refresh-a');
    token = () async => 'device';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'Messaging#getNotificationSettings') {
            return {'authorizationStatus': 1};
          }
          if (call.method == 'Messaging#getToken') {
            return {'token': await token()};
          }
          return null;
        });
    service.beginSession('a');
  });
  tearDown(() async {
    await service.endSession(disableRemote: false);
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'late token from account A cannot register after switching to B',
    () async {
      final delayed = Completer<String>();
      var calls = 0;
      token = () => ++calls == 1 ? delayed.future : Future.value('device-b');
      final api = AuditApi((_) => null);
      useAuditApi(api);
      final old = service.registerDeviceToken(requestPermission: false);
      await until(() => calls == 1);
      await saveTokens(access: 'account-b', refresh: 'refresh-b');
      service.beginSession('b');
      await service.registerDeviceToken(requestPermission: false);
      delayed.complete('device-a');
      await old;
      expect(api.requests.length, 1);
      expect(api.requests.single.headers['Authorization'], 'Bearer account-b');
      expect(api.requests.single.data['token'], 'device-b');
    },
  );

  test(
    'in-flight A registration finishes before B and cannot overwrite B',
    () async {
      final delayed = Completer<Object?>();
      final api = AuditApi(
        (request) => request.headers['Authorization'] == 'Bearer account-a'
            ? delayed.future
            : null,
      );
      useAuditApi(api);
      final old = service.registerDeviceToken(requestPermission: false);
      await until(() => api.requests.isNotEmpty);
      await saveTokens(access: 'account-b', refresh: 'refresh-b');
      service.beginSession('b');
      final next = service.registerDeviceToken(requestPermission: false);
      await Future<void>.delayed(Duration.zero);
      expect(api.requests.length, 1);
      delayed.complete(null);
      await Future.wait([old, next]);
      expect(api.requests.map((r) => r.headers['Authorization']), [
        'Bearer account-a',
        'Bearer account-b',
      ]);
      expect(api.requests.map((r) => r.method), ['POST', 'POST']);
    },
  );

  test(
    'late logout token lookup cannot disable the next account device',
    () async {
      final delayed = Completer<String>();
      var calls = 0;
      token = () => ++calls == 1 ? delayed.future : Future.value('device');
      final api = AuditApi((_) => null);
      useAuditApi(api);
      final logout = service.endSession(disableRemote: true);
      final rejected = expectLater(logout, throwsException);
      await until(() => calls == 1);
      await saveTokens(access: 'account-b', refresh: 'refresh-b');
      service.beginSession('b');
      await service.registerDeviceToken(requestPermission: false);
      delayed.complete('device');
      await rejected;
      expect(api.requests.length, 1);
      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.headers['Authorization'], 'Bearer account-b');
    },
  );
}
