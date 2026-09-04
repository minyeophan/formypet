import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ForegroundNotificationService {
  ForegroundNotificationService._();

  static final instance = ForegroundNotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();

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
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
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
