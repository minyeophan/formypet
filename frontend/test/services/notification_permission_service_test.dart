import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/notification_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const plugin = MethodChannel('dexterous.com/flutter/local_notifications');
  const navigation = MethodChannel('com.formypet/notification_settings');
  final calls = <String>[];
  bool? appAllowed = true;
  List<Map<String, dynamic>>? channels = [];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    appAllowed = true;
    channels = [];
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(plugin, (call) async {
          calls.add(call.method);
          if (call.method == 'areNotificationsEnabled') return appAllowed;
          if (call.method == 'getNotificationChannels') return channels;
          if (call.method == 'requestNotificationsPermission') return true;
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(navigation, (call) async {
          calls.add('${call.method}:${call.arguments}');
          return true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(plugin, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(navigation, null);
  });
  test('inspection never prompts and distinguishes app denial', () async {
    appAllowed = false;
    expect(
      await NotificationPermissionService().inspect(),
      NotificationPermissionStatus.appDisabled,
    );
    expect(calls, ['areNotificationsEnabled']);
  });
  test('missing channel and unknown permission are not enabled', () async {
    expect(
      await NotificationPermissionService().inspect(),
      NotificationPermissionStatus.channelMissing,
    );
    appAllowed = null;
    expect(
      await NotificationPermissionService().inspect(),
      NotificationPermissionStatus.unknown,
    );
  });
  test('channel block is distinct from global app permission', () async {
    channels = [
      {
        'id': 'formypet_reminders',
        'name': 'reminders',
        'importance': 0,
        'ledColor': 0,
        'playSound': true,
        'enableVibration': true,
        'showBadge': true,
        'enableLights': false,
      },
    ];
    expect(
      await NotificationPermissionService().inspect(),
      NotificationPermissionStatus.channelBlocked,
    );
    channels!.single['importance'] = 4;
    expect(
      await NotificationPermissionService().inspect(),
      NotificationPermissionStatus.allowed,
    );
  });
  test(
    'only explicit request prompts and navigation selects reminder channel',
    () async {
      await NotificationPermissionService().request();
      expect(calls, contains('requestNotificationsPermission'));
      expect(
        await NotificationPermissionService().openSettings(channel: true),
        true,
      );
      expect(calls.last, 'openSettings:true');
    },
  );
  test('unsupported platform does not invoke native Android APIs', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      await NotificationPermissionService().inspect(),
      NotificationPermissionStatus.unsupported,
    );
    expect(await NotificationPermissionService().openSettings(), false);
    expect(calls, isEmpty);
  });
}
