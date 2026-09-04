import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'router/app_router.dart';
import 'services/foreground_notification_service.dart';

GoRouter? _appRouter;
RemoteMessage? _pendingMessage;

void _openPushTarget(RemoteMessage message) {
  final type = message.data['type']?.toString();
  final sourceId = message.data['sourceId']?.toString();
  if (sourceId == null || sourceId.isEmpty) return;
  final route = switch (type) {
    'CARE_SCHEDULE_REMINDER' => '/routine/schedule/$sourceId',
    'ROUTINE_REMINDER' => '/routine/$sourceId',
    _ => null,
  };
  if (route == null) return;
  final router = _appRouter;
  if (router == null) {
    _pendingMessage = message;
  } else {
    router.push(route);
  }
}

void _openPushPayload(String payload) {
  try {
    final data = jsonDecode(payload);
    if (data is Map<String, dynamic>) {
      _openPushTarget(RemoteMessage(data: data));
    }
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessageOpenedApp.listen(_openPushTarget);
    await ForegroundNotificationService.instance.initialize(
      (payload) async => _openPushPayload(payload),
    );
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;
      await ForegroundNotificationService.instance.show(
        id: message.hashCode,
        title: notification.title ?? '포마펫 알림',
        body: notification.body ?? '',
        data: message.data,
      );
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _pendingMessage = initialMessage;
  }

  final baseUrl = kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';
  initApiClient(baseUrl);
  const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  if (kakaoNativeAppKey.isEmpty) {
    throw StateError('KAKAO_NATIVE_APP_KEY is not configured');
  }
  await KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);

  runApp(const ProviderScope(child: FormypetApp()));
}

class FormypetApp extends ConsumerWidget {
  const FormypetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    _appRouter = router;
    final pending = _pendingMessage;
    if (pending != null) {
      _pendingMessage = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPushTarget(pending));
    }
    return MaterialApp.router(
      title: '포마펫',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme().copyWith(
        textTheme: GoogleFonts.notoSansKrTextTheme(),
      ),
      routerConfig: router,
    );
  }
}
