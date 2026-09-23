import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationPermissionStatus {
  allowed,
  appDisabled,
  channelBlocked,
  channelMissing,
  unknown,
  unsupported,
}

class NotificationPermissionService {
  static const reminderChannel = 'formypet_reminders';
  static const _navigation = MethodChannel(
    'com.formypet/notification_settings',
  );
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AndroidFlutterLocalNotificationsPlugin? get _android =>
      FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  Future<NotificationPermissionStatus> inspect() async {
    if (!_supported) return NotificationPermissionStatus.unsupported;
    try {
      final enabled = await _android?.areNotificationsEnabled();
      if (enabled == false) return NotificationPermissionStatus.appDisabled;
      if (enabled == null) return NotificationPermissionStatus.unknown;
      final channels = await _android?.getNotificationChannels();
      if (channels == null) return NotificationPermissionStatus.unknown;
      for (final channel in channels) {
        if (channel.id == reminderChannel) {
          return channel.importance == Importance.none
              ? NotificationPermissionStatus.channelBlocked
              : NotificationPermissionStatus.allowed;
        }
      }
      return NotificationPermissionStatus.channelMissing;
    } catch (_) {
      return NotificationPermissionStatus.unknown;
    }
  }

  Future<NotificationPermissionStatus> request() async {
    if (!_supported) return NotificationPermissionStatus.unsupported;
    try {
      await _android?.requestNotificationsPermission();
      return await inspect();
    } catch (_) {
      return NotificationPermissionStatus.unknown;
    }
  }

  Future<bool> openSettings({bool channel = false}) async {
    if (!_supported) return false;
    try {
      return await _navigation.invokeMethod<bool>('openSettings', channel) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>(
      (ref) => NotificationPermissionService(),
    );
