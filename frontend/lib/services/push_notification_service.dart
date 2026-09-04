import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/api_client.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> registerDeviceToken() async {
    if (kIsWeb) return;
    if (Firebase.apps.isEmpty) return;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) await _sendToken(token);

    await _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen(_sendToken);
  }

  Future<void> disableDeviceToken() async {
    if (kIsWeb) return;
    if (Firebase.apps.isEmpty) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await dio.delete(
      '/api/v1/notifications/device-tokens',
      queryParameters: {'token': token},
    );
  }

  Future<void> _sendToken(String token) async {
    await dio.post(
      '/api/v1/notifications/device-tokens',
      data: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
      },
    );
  }
}
