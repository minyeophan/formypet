import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('denied permission after cold start disables the device token without registering it', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FlutterSecureStorage.setMockInitialValues({'access_token': 'test-account'});
    initApiClient('https://example.test');
    final requests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      handler.resolve(Response(requestOptions: request, statusCode: 200));
    }));
    const channel = MethodChannel('plugins.flutter.io/firebase_messaging');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'Messaging#getNotificationSettings') {
        return {'authorizationStatus': 0};
      }
      if (call.method == 'Messaging#getToken') return {'token': 'existing-device'};
      return null;
    });
    final service = PushNotificationService.instance;
    try {
      service.beginSession('account');
      await service.registerDeviceToken(requestPermission: false);
      expect(requests.map((r) => r.method), ['DELETE']);
      expect(requests.single.path, '/api/v1/notifications/device-tokens');
      expect(requests.single.queryParameters['token'], 'existing-device');
    } finally {
      await service.endSession(disableRemote: false);
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}
