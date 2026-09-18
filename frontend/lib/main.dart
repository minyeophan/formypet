import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'router/app_router.dart';
import 'services/foreground_notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/pet_provider.dart';
import 'services/reminder_tap_service.dart';

void _openPushTarget(RemoteMessage message) {
  ReminderTapService.instance.receive({
    ...message.data,
    if (message.messageId != null) 'messageId': message.messageId,
  });
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
        data: {
          ...message.data,
          if (message.messageId != null) 'messageId': message.messageId,
        },
      );
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _openPushTarget(initialMessage);
  }

  final baseUrl = kIsWeb ? 'http://localhost:8083' : 'http://10.0.2.2:8083';
  initApiClient(baseUrl);
  const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  if (kakaoNativeAppKey.isEmpty) {
    throw StateError('KAKAO_NATIVE_APP_KEY is not configured');
  }
  await KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);

  runApp(const ProviderScope(child: FormypetApp()));
}

class FormypetApp extends ConsumerStatefulWidget {
  const FormypetApp({super.key});

  @override
  ConsumerState<FormypetApp> createState() => _FormypetAppState();
}

class _FormypetAppState extends ConsumerState<FormypetApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    ReminderTapService.instance.addListener(_onTap);
  }

  void _onTap() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ReminderTapService.instance.removeListener(_onTap);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final taps = ReminderTapService.instance;
    final auth = ref.watch(authProvider);
    if (taps.pending != null && !auth.isLoading) {
      final generation = taps.generation;
      final pending = taps.take()!;
      final account = auth.profile?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != taps.generation) return;
        if (!auth.isAuthenticated) {
          router.go('/auth');
        } else {
          _handlePushTarget(router, pending, generation, account);
        }
      });
    }
    return MaterialApp.router(
      title: '포마펫',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scaffoldMessengerKey: _messenger,
      routerConfig: router,
    );
  }

  Future<void> _handlePushTarget(
    GoRouter router,
    ReminderTap tap,
    int generation,
    String? account,
  ) async {
    bool current() =>
        mounted &&
        generation == ReminderTapService.instance.generation &&
        ref.read(authProvider).isAuthenticated &&
        ref.read(authProvider).profile?.id == account;
    try {
      if (!current()) return;
      final found = await ref
          .read(petProvider.notifier)
          .activateReminderTarget(
            sourceId: tap.sourceId,
            isSchedule: tap.isSchedule,
            isRequestCurrent: current,
          );
      if (!current()) return;
      if (found) {
        router.push(tap.route);
      } else {
        _messenger.currentState?.showSnackBar(
          const SnackBar(content: Text('연결된 일정 내용을 찾을 수 없어요.')),
        );
      }
    } catch (_) {
      if (!current()) return;
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: const Text('일정을 불러오지 못했어요. 연결 상태를 확인해 주세요.'),
          action: SnackBarAction(
            label: '재시도',
            onPressed: () {
              if (current()) {
                _handlePushTarget(router, tap, generation, account);
              }
            },
          ),
        ),
      );
    }
  }
}
