import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'without Firebase, repeated token registration and disabling are safe',
    () async {
      expect(Firebase.apps, isEmpty);
      final service = PushNotificationService.instance;
      for (var i = 0; i < 3; i++) {
        await service.registerDeviceToken();
        await service.disableDeviceToken();
      }
      expect(Firebase.apps, isEmpty);
    },
  );
}
