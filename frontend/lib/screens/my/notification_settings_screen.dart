import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../services/notification_permission_service.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  NotificationPermissionStatus? _permission;
  bool _permissionBusy = false;
  String? _deviceError;
  int _inspection = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_inspect());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(ref.read(notificationSettingsProvider.notifier).refresh());
    if (!_permissionBusy) unawaited(_inspect());
  }

  Future<void> _inspect() async {
    final sequence = ++_inspection;
    final value = await ref
        .read(notificationPermissionServiceProvider)
        .inspect();
    if (mounted && sequence == _inspection) setState(() => _permission = value);
  }

  Future<void> _requestPermission() async {
    if (_permissionBusy) return;
    final auth = ref.read(authProvider);
    if (auth.isLoading || !auth.isAuthenticated || auth.profile == null) return;
    ++_inspection;
    setState(() {
      _permissionBusy = true;
      _deviceError = null;
    });
    final result = await ref
        .read(notificationPermissionServiceProvider)
        .request();
    if (!mounted) return;
    setState(() {
      _permission = result;
      _permissionBusy = false;
    });
    final current = ref.read(authProvider);
    if (current.sessionEpoch != auth.sessionEpoch ||
        current.isLoading ||
        !current.isAuthenticated) {
      return;
    }
    // Registration failure is separate from OS permission.
    try {
      await PushNotificationService.instance.registerDeviceToken(
        sessionKey: auth.profile!.id,
        requestPermission: false,
      );
    } catch (_) {
      if (mounted && ref.read(authProvider).sessionEpoch == auth.sessionEpoch) {
        setState(() => _deviceError = '기기 연결을 갱신하지 못했어요. 앱에 다시 들어오면 재시도합니다.');
      }
    }
  }

  Future<void> _openSettings() async {
    final opened = await ref
        .read(notificationPermissionServiceProvider)
        .openSettings(
          channel: _permission == NotificationPermissionStatus.channelBlocked,
        );
    if (mounted && !opened) {
      setState(() => _deviceError = '기기 설정을 열지 못했어요. 휴대폰 설정에서 앱 알림을 확인해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final auth = ref.watch(authProvider);
    final ready = auth.isAuthenticated && !auth.isLoading;
    final busy = settings.loading || settings.saving || !ready;
    final statusText = switch (_permission) {
      null => '확인 중…',
      NotificationPermissionStatus.allowed => '허용됨',
      NotificationPermissionStatus.appDisabled => '앱 알림이 꺼져 있어요',
      NotificationPermissionStatus.channelBlocked => '일정 알림 채널이 꺼져 있어요',
      NotificationPermissionStatus.channelMissing => '일정 알림 채널을 확인할 수 없어요',
      NotificationPermissionStatus.unknown => '권한 상태를 확인하지 못했어요',
      NotificationPermissionStatus.unsupported => '이 기기의 권한 확인은 지원 준비 중이에요',
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '알림 설정',
        showBackButton: true,
        centerTitle: true,
        onBack: () =>
            context.canPop() ? context.pop() : context.go('/my/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: AppText(
                          '루틴·케어 일정 알림',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (settings.enabled != null)
                        Switch(
                          value: settings.enabled!,
                          onChanged: busy
                              ? null
                              : ref
                                    .read(notificationSettingsProvider.notifier)
                                    .save,
                        )
                      else
                        const AppText('확인 필요', fontSize: 12),
                    ],
                  ),
                  const AppText(
                    '같은 계정으로 로그인한 모든 기기에 적용돼요. 커뮤니티 알림 내역은 이 설정과 별개예요.',
                    fontSize: 13,
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    '끄면 새 일정 알림이 생성되지 않으며 기존 내역은 유지돼요. 다시 켜면 최근 놓친 일정이 도착할 수 있어요.',
                    fontSize: 13,
                  ),
                  if (settings.loading || settings.saving) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    AppText(
                      settings.saving ? '저장 중…' : '설정 확인 중…',
                      fontSize: 12,
                    ),
                  ],
                  if (settings.error != null) ...[
                    const SizedBox(height: 12),
                    AppText(
                      settings.error!,
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : ref
                                .read(notificationSettingsProvider.notifier)
                                .refresh,
                      child: const Text('현재 설정 다시 확인'),
                    ),
                    if (settings.retryValue != null)
                      TextButton(
                        onPressed: busy || settings.enabled == null
                            ? null
                            : () => ref
                                  .read(notificationSettingsProvider.notifier)
                                  .save(settings.retryValue!),
                        child: Text(
                          settings.retryValue! ? '켜기로 다시 저장' : '끄기로 다시 저장',
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    '이 기기의 알림 권한',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 8),
                  AppText(statusText, fontSize: 14),
                  if (_permission ==
                      NotificationPermissionStatus.channelMissing)
                    const AppText(
                      'Android 7에서는 알림 채널을 사용하지 않아요. Android 8 이상에서는 기기 설정에서 일정 알림 채널을 확인해 주세요.',
                      fontSize: 12,
                    ),
                  const SizedBox(height: 8),
                  const AppText(
                    '계정 설정과 기기 권한이 모두 켜져 있어야 해요. 네트워크나 절전 설정에 따라 도착이 지연될 수 있어요.',
                    fontSize: 13,
                  ),
                  if (_permission == NotificationPermissionStatus.appDisabled)
                    TextButton(
                      onPressed: _permissionBusy || !ready
                          ? null
                          : _requestPermission,
                      child: const Text('알림 권한 요청'),
                    ),
                  if (_permission != null &&
                      _permission != NotificationPermissionStatus.unsupported)
                    TextButton(
                      onPressed: _permissionBusy ? null : _openSettings,
                      child: const Text('기기 알림 설정 열기'),
                    ),
                  if (_permission == NotificationPermissionStatus.unknown ||
                      _permission ==
                          NotificationPermissionStatus.channelMissing)
                    TextButton(
                      onPressed: _permissionBusy ? null : _inspect,
                      child: const Text('권한 다시 확인'),
                    ),
                  if (_permissionBusy) const LinearProgressIndicator(),
                  if (_deviceError != null)
                    AppText(
                      _deviceError!,
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
