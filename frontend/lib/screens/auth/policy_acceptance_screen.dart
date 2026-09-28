import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/policy_service.dart';
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

class PolicyHistoryScreen extends StatefulWidget {
  const PolicyHistoryScreen({super.key});
  @override
  State<PolicyHistoryScreen> createState() => _PolicyHistoryState();
}

class _PolicyHistoryState extends State<PolicyHistoryScreen> {
  late Future<List<dynamic>> _history;
  @override
  void initState() {
    super.initState();
    _history = PolicyService().history();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('나의 동의 이력')),
    body: FutureBuilder<List<dynamic>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => _history = PolicyService().history()),
              child: const Text('다시 시도'),
            ),
          );
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Text('저장된 동의 이력이 없습니다. 과거 동의를 추정하지 않습니다.'),
          );
        }
        const labels = {
          'ACCEPTED': '이용약관 동의',
          'AGE14_CONFIRMED': '만 14세 이상 확인',
          'NOTICE_ACKNOWLEDGED': '처리방침 안내 확인',
        };
        return ListView(
          children: [
            for (final item in snapshot.data!)
              ListTile(
                title: Text(
                  labels[item['action']] ?? item['action'].toString(),
                ),
                subtitle: Text(
                  '${item['document_version']} · ${item['recorded_at']}',
                ),
                onTap: () => context.push(
                  '/policies/${Uri.encodeComponent(item['document_type'] as String)}/${Uri.encodeComponent(item['document_version'] as String)}',
                ),
              ),
          ],
        );
      },
    ),
  );
}
