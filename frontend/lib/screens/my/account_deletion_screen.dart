import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

  bool get _isKakao =>
      ref.read(authProvider).profile?.registrationSource == 'KAKAO';

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_submitting || (!_isKakao && _password.text.isEmpty)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정을 탈퇴할까요?'),
        content: const Text(
          '탈퇴하면 계정과 연결된 기록, 게시글, 댓글, 투표, 사진이 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final accepted = await ref
          .read(authProvider.notifier)
          .deleteAccount(password: _isKakao ? null : _password.text);
      if (!accepted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('탈퇴 요청을 접수했습니다. 첨부파일과 카카오 연결 정리가 이어질 수 있습니다.'),
        ),
      );
      context.go('/auth');
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is DioException
            ? parseApiError(error).detail ?? '탈퇴 요청을 처리하지 못했어요. 다시 시도해 주세요.'
            : '탈퇴 요청을 처리하지 못했어요. 다시 시도해 주세요.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '회원 탈퇴',
        showBackButton: true,
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const AppText(
            '탈퇴하면 계정 정보와 함께 반려동물 기록, 게시글, 댓글, 투표, 좋아요, 첨부파일이 삭제됩니다.',
            fontSize: 15,
            color: AppColors.text,
          ),
          const SizedBox(height: 12),
          const AppText(
            '삭제 요청 후에는 다시 로그인할 수 없습니다. 카카오 연결과 첨부파일 정리는 서버에서 이어질 수 있습니다.',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          if (_isKakao) ...[
            const SizedBox(height: 24),
            const AppText(
              '탈퇴를 진행하면 카카오톡 앱으로 본인 확인을 요청합니다. 앱을 사용할 수 없으면 카카오계정 로그인으로 이어집니다.',
              fontSize: 14,
              color: AppColors.text,
            ),
          ] else ...[
            const SizedBox(height: 24),
            TextField(
              controller: _password,
              enabled: !_submitting,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '현재 비밀번호',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _delete(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppText(_error!, fontSize: 13, color: AppColors.danger),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submitting || (!_isKakao && _password.text.isEmpty)
                ? null
                : _delete,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppText('계정 탈퇴', color: AppColors.white),
          ),
        ],
      ),
    );
  }
}
