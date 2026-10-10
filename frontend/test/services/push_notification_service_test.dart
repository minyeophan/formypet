import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'without Firebase, repeated token registration and disabling are safe',
    () async {
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final storageCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (call) async {
            storageCalls.add(call);
            return null;
          });
      expect(Firebase.apps, isEmpty);
      final service = PushNotificationService.instance;
      try {
        for (var i = 0; i < 3; i++) {
          await service.registerDeviceToken();
          await service.disableDeviceToken();
        }
        // Let any unawaited storage reads reach the mock channel before
        // asserting the no-Firebase path remains isolated from secure storage.
        await Future<void>.delayed(Duration.zero);
        expect(storageCalls, isEmpty);
        expect(Firebase.apps, isEmpty);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(storageChannel, null);
      }
    },
  );
}
