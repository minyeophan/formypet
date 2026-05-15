import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_text.dart';

class WriteScreen extends ConsumerStatefulWidget {
  const WriteScreen({super.key});

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _category = 'general';
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_contentCtrl.text.trim().isEmpty) {
      setState(() => _error = '내용을 입력해주세요');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(communityProvider.notifier).createPost(
            content: _contentCtrl.text.trim(),
            title: _titleCtrl.text.trim().isNotEmpty
                ? _titleCtrl.text.trim()
                : null,
            category: _category,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('글쓰기', fontWeight: FontWeight.bold),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const AppText('게시', color: Colors.blue,
                    fontWeight: FontWeight.bold),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                  labelText: '카테고리', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'general', child: AppText('일반')),
                DropdownMenuItem(value: 'dog', child: AppText('강아지')),
                DropdownMenuItem(value: 'cat', child: AppText('고양이')),
                DropdownMenuItem(value: 'rabbit', child: AppText('토끼')),
                DropdownMenuItem(value: 'hamster', child: AppText('햄스터')),
                DropdownMenuItem(value: 'bird', child: AppText('새')),
                DropdownMenuItem(value: 'other', child: AppText('기타')),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                  hintText: '제목 (선택, 최대 120자)',
                  border: OutlineInputBorder()),
              maxLength: 120,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                  hintText: '내용을 입력해주세요',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              AppText(_error!, color: Colors.red),
            ],
          ],
        ),
      ),
    );
  }
}
