import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/policy_service.dart';
import 'my_policy_data.dart';

class MyPoliciesScreen extends StatelessWidget {
  const MyPoliciesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('약관 및 정책'),
      leading: BackButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/auth');
          }
        },
      ),
    ),
    body: ListView(
      children: [
        for (final entry in policyTitles.entries)
          ListTile(
            title: Text(entry.value),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/my/policies/${entry.key}'),
          ),
      ],
    ),
  );
}

class MyPolicyDetailScreen extends ConsumerStatefulWidget {
  final String policyId;
  final String? version;
  const MyPolicyDetailScreen({super.key, required this.policyId, this.version});
  @override
  ConsumerState<MyPolicyDetailScreen> createState() => _PolicyDetailState();
}

class _PolicyDetailState extends ConsumerState<MyPolicyDetailScreen> {
  PolicyService get _service => ref.read(policyServiceProvider);
  late Future<Map<String, dynamic>> _document;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _document = policyTitles.containsKey(widget.policyId)
        ? _service.document(widget.policyId, version: widget.version)
        : Future.error(ArgumentError('Unknown policy'));
  }

  Future<void> _web() async {
    try {
      await _service.openWeb(widget.policyId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(policyTitles[widget.policyId] ?? '정책 전문'),
      leading: BackButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/my/policies');
          }
        },
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _document,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  !policyTitles.containsKey(widget.policyId)
                      ? '약관을 찾을 수 없어요'
                      : snapshot.error is StateError
                      ? '정책 전문 게시 준비 중입니다.'
                      : '정책 전문을 불러오지 못했어요.',
                ),
                TextButton(
                  onPressed: () => setState(_load),
                  child: const Text('다시 시도'),
                ),
                TextButton(onPressed: _web, child: const Text('공개 웹페이지 열기')),
              ],
            ),
          );
        }
        final doc = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              doc['title'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '버전 ${doc['version']}\n게시일 ${doc['publishedAt']}\n시행일 ${doc['effectiveAt']}',
            ),
            const SizedBox(height: 20),
            SelectableText(doc['body'] as String),
            TextButton(onPressed: _web, child: const Text('공개 웹페이지 열기')),
          ],
        );
      },
    ),
  );
}
