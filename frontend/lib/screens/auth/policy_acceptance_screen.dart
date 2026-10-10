import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/policy_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import 'policy_consent_dialog.dart';

class PolicyAcceptanceScreen extends ConsumerStatefulWidget {
  const PolicyAcceptanceScreen({super.key});
  @override
  ConsumerState<PolicyAcceptanceScreen> createState() =>
      _PolicyAcceptanceState();
}

class _PolicyAcceptanceState extends ConsumerState<PolicyAcceptanceScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final acceptance = await collectPolicyAcceptance(
        context,
        policyService: ref.read(policyServiceProvider),
      );
      if (acceptance != null && mounted) {
        await ref.read(authProvider.notifier).acceptPolicies(acceptance);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '정책 확인을 완료하지 못했어요. 최신 전문을 다시 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('서비스 이용약관 확인')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          '이용약관 동의 이력이 없거나 새로운 확인이 필요합니다. 동의하지 않아도 정책 열람, 문의, 알림 해제, 회원 탈퇴를 할 수 있습니다.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _accept,
          child: const Text('확인하고 계속'),
        ),
        if (_error != null) Text(_error!),
        TextButton(
          onPressed: () => context.push('/my/policies'),
          child: const Text('약관 및 정책'),
        ),
        TextButton(
          onPressed: () => context.push('/policy-history'),
          child: const Text('나의 동의 이력'),
        ),
        TextButton(
          onPressed: () => context.push('/my/inquiry'),
          child: const Text('문의하기'),
        ),
        TextButton(
          onPressed: () => context.push('/my/settings/notifications'),
          child: const Text('알림 수신 해제'),
        ),
        TextButton(
          onPressed: () => context.push('/my/settings/delete-account'),
          child: const Text('회원 탈퇴'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  try {
                    await ref.read(authProvider.notifier).logout();
                  } catch (_) {
                    if (mounted) {
                      setState(() => _error = '로그아웃하지 못했어요. 다시 시도해 주세요.');
                    }
                  }
                },
          child: const Text('로그아웃'),
        ),
      ],
    ),
  );
}

class PolicyHistoryScreen extends ConsumerStatefulWidget {
  const PolicyHistoryScreen({super.key});
  @override
  ConsumerState<PolicyHistoryScreen> createState() => _PolicyHistoryState();
}

class _PolicyHistoryState extends ConsumerState<PolicyHistoryScreen> {
  late Future<List<dynamic>> _history;
  @override
  void initState() {
    super.initState();
    _history = ref.read(policyServiceProvider).history();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppHeader(
      title: '나의 동의 이력',
      showBackButton: true,
      onBack: () => context.pop(),
    ),
    body: FutureBuilder<List<dynamic>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppText(
                  '동의 이력을 불러오지 못했어요',
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(
                    () => _history = ref.read(policyServiceProvider).history(),
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }
        final history = snapshot.data ?? const <dynamic>[];
        if (history.isEmpty) {
          return const Center(
            child: AppText('아직 동의 이력이 없어요', color: AppColors.textSecondary),
          );
        }
        const labels = {
          'ACCEPTED': '이용약관 동의',
          'AGE14_CONFIRMED': '만 14세 이상 확인',
          'NOTICE_ACKNOWLEDGED': '처리방침 안내 확인',
        };
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            for (final item in history)
              Card(
                color: AppColors.surface,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(
                    '/policies/${Uri.encodeComponent(item['document_type'] as String)}/${Uri.encodeComponent(item['document_version'] as String)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          labels[item['action']] ?? item['action'].toString(),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          '${_policyTypeLabel(item['document_type'])} · ${item['document_version']}',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppText(
                            _formatRecordedAt(item['recorded_at']),
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

String _policyTypeLabel(dynamic type) => switch (type) {
  'terms' => '약관',
  'privacy' => '개인정보 처리방침',
  'account-deletion.html' => '회원 탈퇴 안내',
  _ => type?.toString() ?? '정책',
};

String _formatRecordedAt(dynamic value) {
  if (value is! String) return value?.toString() ?? '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('yyyy.MM.dd · HH:mm').format(parsed.toLocal());
}
