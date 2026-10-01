import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/notification_settings_provider.dart';
import 'package:frontend/screens/my/notification_settings_screen.dart';
import 'package:frontend/services/notification_permission_service.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ScreenSettings extends NotificationService {
  bool enabled = true;
  int reads = 0;
  Completer<bool>? pending;
  @override
  Future<bool> getSettings() async {
    reads++;
    return enabled;
  }

  @override
  Future<bool> updateSettings(bool value) async {
    if (pending != null) return pending!.future;
    return enabled = value;
  }
}

class ScreenPermission extends NotificationPermissionService {
  int requests = 0;
  int inspections = 0;
  NotificationPermissionStatus status =
      NotificationPermissionStatus.appDisabled;
  @override
  Future<NotificationPermissionStatus> inspect() async {
    inspections++;
    return status;
  }

  @override
  Future<NotificationPermissionStatus> request() async {
    requests++;
    return status = NotificationPermissionStatus.allowed;
  }

  @override
  Future<bool> openSettings({bool channel = false}) async => true;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> pump(
    WidgetTester tester,
    ScreenSettings service,
    ScreenPermission permission,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier.test(
              const AuthState(
                isLoading: false,
                isAuthenticated: true,
                profile: UserProfile(
                  id: '1',
                  email: 'test@example.test',
                  nickname: 'test',
                ),
              ),
            ),
          ),
          notificationSettingsServiceProvider.overrideWithValue(service),
          notificationPermissionServiceProvider.overrideWithValue(permission),
        ],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('account preference is separate from denied OS permission', (
    tester,
  ) async {
    final service = ScreenSettings();
    final permission = ScreenPermission();
    await pump(tester, service, permission);
    expect(find.text('루틴·케어 일정 알림'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, true);
    expect(find.text('앱 알림이 꺼져 있어요'), findsOneWidget);
    expect(permission.requests, 0);
    await tester.tap(find.text('알림 권한 요청'));
    await tester.pumpAndSettle();
    expect(permission.requests, 1);
    expect(find.text('허용됨'), findsOneWidget);
    expect(service.enabled, true);
  });
  testWidgets('pending write disables switch until server confirms', (
    tester,
  ) async {
    final service = ScreenSettings()..pending = Completer<bool>();
    await pump(tester, service, ScreenPermission());
    await tester.tap(find.byType(Switch));
    await tester.pump();
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, true);
    expect(toggle.onChanged, isNull);
    service.pending!.complete(false);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });
  testWidgets(
    'resume refreshes account and device state without permission prompt',
    (tester) async {
      final service = ScreenSettings();
      final permission = ScreenPermission();
      await pump(tester, service, permission);
      service.enabled = false;
      permission.status = NotificationPermissionStatus.channelBlocked;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.reads, greaterThan(1));
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      expect(find.text('일정 알림 채널이 꺼져 있어요'), findsOneWidget);
      expect(permission.requests, 0);
    },
  );
}
