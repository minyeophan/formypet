import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

class NotificationSettingsState {
  final bool? enabled;
  final bool loading;
  final bool saving;
  final String? error;
  final bool uncertain;
  final bool? retryValue;
  const NotificationSettingsState({
    this.enabled,
    this.loading = false,
    this.saving = false,
    this.error,
    this.uncertain = false,
    this.retryValue,
  });
}

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsState> {
  final NotificationService _service;
  final bool active;
  bool _refreshAfterSave = false;
  int _read = 0;

  NotificationSettingsNotifier(this._service, {required this.active})
    : super(const NotificationSettingsState()) {
    if (active) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!mounted || !active) return;
    if (state.saving) {
      _refreshAfterSave = true;
      return;
    }
    final read = ++_read;
    final previous = state;
    state = NotificationSettingsState(
      enabled: previous.enabled,
      loading: true,
      uncertain: previous.uncertain,
      error: previous.uncertain ? previous.error : null,
      retryValue: previous.uncertain ? previous.retryValue : null,
    );
    try {
      final enabled = await _service.getSettings();
      if (!mounted || read != _read) return;
      state = NotificationSettingsState(
        enabled: enabled,
        uncertain: previous.uncertain,
        error: previous.uncertain ? previous.error : null,
        retryValue: previous.uncertain ? previous.retryValue : null,
      );
    } catch (_) {
      if (!mounted || read != _read) return;
      state = NotificationSettingsState(
        enabled: previous.enabled,
        uncertain: previous.uncertain,
        retryValue: previous.retryValue,
        error: previous.uncertain
            ? '저장 결과와 현재 설정을 확인하지 못했어요. 연결 후 다시 확인해 주세요.'
            : '설정을 불러오지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.',
      );
    }
  }

  Future<void> save(bool enabled) async {
    if (!mounted ||
        !active ||
        state.loading ||
        state.saving ||
        state.enabled == null) {
      return;
    }
    ++_read;
    final previous = state.enabled;
    state = NotificationSettingsState(enabled: previous, saving: true);
    try {
      final confirmed = await _service.updateSettings(enabled);
      if (!mounted) return;
      state = NotificationSettingsState(enabled: confirmed);
    } catch (error) {
      if (!mounted) return;
      final status = error is DioException ? error.response?.statusCode : null;
      final uncertain = status == null || status >= 500 || status == 408;
      state = NotificationSettingsState(
        enabled: previous,
        uncertain: uncertain,
        retryValue: enabled,
        error: uncertain
            ? '저장 결과를 확인하지 못했어요. 아래는 조회 시점의 설정이며, 이전 요청이 나중에 반영될 수 있어요.'
            : '설정을 저장하지 못했어요. 다시 시도해 주세요.',
      );
      if (uncertain) _refreshAfterSave = true;
    }
    if (_refreshAfterSave) {
      _refreshAfterSave = false;
      await refresh();
    }
  }
}

final notificationSettingsServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
final notificationSettingsProvider =
    StateNotifierProvider.autoDispose<
      NotificationSettingsNotifier,
      NotificationSettingsState
    >((ref) {
      // Recreate on every login lifetime, including re-login to the same account.
      // A credential refresh does not rebuild this provider.
      final session = ref.watch(
        authProvider.select(
          (auth) => (
            auth.sessionEpoch,
            auth.profile?.id,
            auth.isAuthenticated && !auth.isLoading,
          ),
        ),
      );
      return NotificationSettingsNotifier(
        ref.read(notificationSettingsServiceProvider),
        active: session.$3 && session.$2 != null,
      );
    });
