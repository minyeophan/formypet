import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ForegroundNotificationService {
  ForegroundNotificationService._();

  static final instance = ForegroundNotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Set<String> _shown = {};

  Future<void> initialize(Future<void> Function(String payload) onTap) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) await onTap(payload);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'formypet_reminders',
          '포마펫 일정 알림',
          description: '일정과 루틴 알림을 표시합니다.',
          importance: Importance.high,
        ));
    _initialized = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null && payload.isNotEmpty) {
      await onTap(payload);
    }
  }

  Future<void> cancelAll() async {
    _shown.clear();
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final identity = data['messageId']?.toString();
    if (identity != null && !_shown.add(identity)) return;
    if (_shown.length > 100) _shown.remove(_shown.first);
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'formypet_reminders',
          '포마펫 일정 알림',
          channelDescription: '일정과 루틴 알림을 표시합니다.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }
}
