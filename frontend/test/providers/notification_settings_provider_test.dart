import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/notification_settings_provider.dart';
import 'package:frontend/services/notification_service.dart';

class ControlledSettings extends NotificationService {
  final reads = <Completer<bool>>[];
  final writes = <Completer<bool>>[];
  final values = <bool>[];
  @override
  Future<bool> getSettings() {
    final result = Completer<bool>();
    reads.add(result);
    return result.future;
  }

  @override
  Future<bool> updateSettings(bool enabled) {
    values.add(enabled);
    final result = Completer<bool>();
    writes.add(result);
    return result.future;
  }
}

class ChangingAuth extends AuthNotifier {
  ChangingAuth()
    : super.test(
        const AuthState(
          isLoading: false,
          isAuthenticated: true,
          profile: UserProfile(
            id: '1',
            email: 'test@example.test',
            nickname: 'test',
          ),
        ),
      );
  void replace(AuthState next) => state = next;
}

void main() {
  for (final account in ['1', '2']) {
    test(
      'new login epoch for account $account cannot receive old PATCH completion',
      () async {
        final api = ControlledSettings();
        final auth = ChangingAuth();
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith((ref) => auth),
            notificationSettingsServiceProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          notificationSettingsProvider,
          (_, next) {},
        );
        addTearDown(subscription.close);
        final old = container.read(notificationSettingsProvider.notifier);
        api.reads.single.complete(true);
        await Future<void>.delayed(Duration.zero);
        final write = old.save(false);
        auth.replace(
          AuthState(
            isLoading: false,
            isAuthenticated: true,
            sessionEpoch: 1,
            profile: UserProfile(
              id: account,
              email: 'test@example.test',
              nickname: 'next',
            ),
          ),
        );
        final next = container.read(notificationSettingsProvider.notifier);
        expect(identical(next, old), false);
        api.reads.last.complete(true);
        await Future<void>.delayed(Duration.zero);
        api.writes.single.complete(false);
        await write;
        expect(container.read(notificationSettingsProvider).enabled, true);
        auth.replace(
          auth.state.copyWith(
            profile: UserProfile(
              id: account,
              email: 'test@example.test',
              nickname: 'edited',
            ),
          ),
        );
        expect(
          identical(
            next,
            container.read(notificationSettingsProvider.notifier),
          ),
          true,
        );
      },
    );
  }
  test('unknown and failed loads never mean disabled', () async {
    final api = ControlledSettings();
    final settings = NotificationSettingsNotifier(api, active: true);
    addTearDown(settings.dispose);
    expect(settings.state.enabled, isNull);
    api.reads.single.completeError(Exception('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(settings.state.enabled, isNull);
    expect(settings.state.error, isNotNull);
    final retry = settings.refresh();
    api.reads.last.complete(true);
    await retry;
    expect(settings.state.enabled, true);
    expect(settings.state.error, isNull);
  });
  test(
    'save waits for confirmation, serializes writes and coalesces resume',
    () async {
      final api = ControlledSettings();
      final settings = NotificationSettingsNotifier(api, active: true);
      addTearDown(settings.dispose);
      api.reads.single.complete(true);
      await Future<void>.delayed(Duration.zero);
      final saving = settings.save(false);
      await settings.save(true);
      await settings.refresh();
      await settings.refresh();
      expect(api.values, [false]);
      expect(settings.state.enabled, true);
      api.writes.single.complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(api.reads.length, 2);
      api.reads.last.complete(false);
      await saving;
      expect(settings.state.enabled, false);
      expect(settings.state.saving, false);
    },
  );
  test(
    'timeout reads current value but retains uncertainty without replay',
    () async {
      final api = ControlledSettings();
      final settings = NotificationSettingsNotifier(api, active: true);
      addTearDown(settings.dispose);
      api.reads.single.complete(true);
      await Future<void>.delayed(Duration.zero);
      final saving = settings.save(false);
      api.writes.single.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/settings'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      api.reads.last.complete(true);
      await saving;
      expect(settings.state.enabled, true);
      expect(settings.state.uncertain, true);
      expect(settings.state.retryValue, false);
      expect(api.values, [false]);
    },
  );
  test('refresh prevents overlapping edit and stale read overwrite', () async {
    final api = ControlledSettings();
    final settings = NotificationSettingsNotifier(api, active: true);
    addTearDown(settings.dispose);
    api.reads.single.complete(true);
    await Future<void>.delayed(Duration.zero);
    final refresh = settings.refresh();
    await settings.save(false);
    expect(api.writes, isEmpty);
    api.reads.last.complete(false);
    await refresh;
    expect(settings.state.enabled, false);
  });
  test('disposed login lifetime ignores old completions', () async {
    final api = ControlledSettings();
    final old = NotificationSettingsNotifier(api, active: true);
    old.dispose();
    final next = NotificationSettingsNotifier(api, active: true);
    addTearDown(next.dispose);
    api.reads.last.complete(false);
    await Future<void>.delayed(Duration.zero);
    api.reads.first.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(next.state.enabled, false);
  });
  test('signed out lifetime does not read or write', () async {
    final api = ControlledSettings();
    final settings = NotificationSettingsNotifier(api, active: false);
    addTearDown(settings.dispose);
    await settings.refresh();
    await settings.save(true);
    expect(api.reads, isEmpty);
    expect(api.writes, isEmpty);
  });
}
