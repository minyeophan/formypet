import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/preparing_toast.dart';
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
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
                label: '알림 설정',
                icon: Icons.notifications_none_rounded,
                onTap: () => context.push('/notifications'),
              ),
              MyMenuRow(
                label: '테마 설정',
                icon: Icons.palette_outlined,
                showTopBorder: true,
                onTap: () => showPreparingToast(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MyMenuCard(
            title: '위험 액션',
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
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText(
              '로그아웃할까요?',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            const SizedBox(height: 8),
            const AppText(
              '이 기기에서 계정 연결을 종료합니다.',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const AppText('로그아웃', color: AppColors.white),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('취소', color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/my');
}
