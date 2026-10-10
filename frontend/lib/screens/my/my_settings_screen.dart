import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_confirmation_sheet.dart';
import '../../widgets/app_text.dart';
import 'my_widgets.dart';

class MySettingsScreen extends ConsumerStatefulWidget {
  const MySettingsScreen({super.key});

  @override
  ConsumerState<MySettingsScreen> createState() => _MySettingsScreenState();
}

class _MySettingsScreenState extends ConsumerState<MySettingsScreen> {
  bool _loggingOut = false;
  String? _error;

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showLogoutConfirmationSheet(context);
    if (confirmed != true || !mounted) return;
    setState(() {
      _loggingOut = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      if (mounted) {
        setState(() => _error = '로그아웃하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '설정',
        showBackButton: true,
        centerTitle: true,
        onBack: () => _goBack(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          MyMenuCard(
            title: '계정',
            children: [
              MyMenuRow(
                label: '내 프로필 편집',
                icon: Icons.person_outline_rounded,
                onTap: () => context.push('/my/profile'),
              ),
              MyMenuRow(
                label: '계정 정보',
                icon: Icons.badge_outlined,
                showTopBorder: true,
                onTap: () => context.push('/my/profile'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MyMenuCard(
            title: '앱 설정',
            children: [
              MyMenuRow(
                label: '약관 및 정책',
                icon: Icons.description_outlined,
                onTap: () => context.push('/my/policies'),
              ),
              MyMenuRow(
                label: '나의 동의 이력',
                icon: Icons.history,
                onTap: () => context.push('/policy-history'),
              ),
              MyMenuRow(
                label: '알림 설정',
                icon: Icons.notifications_active_outlined,
                onTap: () => context.push('/my/settings/notifications'),
              ),
              MyMenuRow(
                showTopBorder: true,
                label: '알림 내역',
                icon: Icons.notifications_none_rounded,
                onTap: () => context.push('/notifications'),
              ),
              MyMenuRow(
                label: '차단 목록',
                icon: Icons.block_rounded,
                showTopBorder: true,
                onTap: () => context.push('/my/blocked-users'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MyMenuCard(
            title: '계정 관리',
            danger: true,
            children: [
              MyMenuRow(
                label: '로그아웃',
                icon: Icons.logout_rounded,
                danger: true,
                onTap: _loggingOut ? null : _logout,
                trailing: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SizedBox.shrink(),
              ),
              MyMenuRow(
                label: '회원 탈퇴',
                icon: Icons.person_remove_alt_1_outlined,
                danger: true,
                showTopBorder: true,
                onTap: _loggingOut
                    ? null
                    : () => context.push('/my/settings/delete-account'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            AppText(_error!, fontSize: 12, color: AppColors.danger),
          ],
        ],
      ),
    );
  }
}

Future<bool?> showLogoutConfirmationSheet(BuildContext context) {
  return showAppConfirmationSheet(
    context,
    title: '로그아웃할까요?',
    message: '이 기기에서 계정 연결을 종료합니다.',
    confirmLabel: '로그아웃',
    confirmKey: const Key('logout-confirm-button'),
    cancelKey: const Key('logout-cancel-button'),
  );
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/my');
}
