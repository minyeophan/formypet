import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/community_provider.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';

class WriteScreen extends ConsumerStatefulWidget {
  const WriteScreen({super.key});

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _pollQuestionCtrl = TextEditingController();
  final _pollOptionCtrls = [TextEditingController(), TextEditingController()];
  final _imagePicker = ImagePicker();
  final _files = <XFile>[];
  String _category = 'FREE';
  bool _showPoll = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _pollQuestionCtrl.dispose();
    for (final ctrl in _pollOptionCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _files
        ..clear()
        ..addAll(picked.take(5));
    });
  }

  Future<void> _submit() async {
    if (_contentCtrl.text.trim().isEmpty) {
      setState(() => _error = '내용을 입력해 주세요');
      return;
    }
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(communityProvider.notifier)
          .createPost(
            content: _contentCtrl.text.trim(),
            title: _titleCtrl.text.trim().isNotEmpty
                ? _titleCtrl.text.trim()
                : null,
            category: _category,
            files: _files,
            poll: _buildPollDraft(),
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  PollDraft? _buildPollDraft() {
    if (!_showPoll) return null;
    final question = _pollQuestionCtrl.text.trim();
    final options = _pollOptionCtrls
        .map((ctrl) => ctrl.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) return null;
    return PollDraft(question: question, options: options);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppText('글쓰기', fontWeight: FontWeight.bold),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: BackButton(
          onPressed: () async {
            await dismissKeyboardBeforeTransition(context);
            if (context.mounted) {
              context.pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppText(
                    '게시',
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: '카테고리',
                    border: OutlineInputBorder(),
                  ),
                  items: kCommunityCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: AppText(
                            kCommunityCategoryLabels[category] ?? category,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _category = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: '제목 (선택, 최대 120자)',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 120,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentCtrl,
                  decoration: const InputDecoration(
                    hintText: '내용을 입력해 주세요',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 9,
                  maxLines: 14,
                ),
                if (_showPoll) ...[
                  const SizedBox(height: 12),
                  _PollPanel(
                    questionCtrl: _pollQuestionCtrl,
                    optionCtrls: _pollOptionCtrls,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  AppText(_error!, color: Colors.red),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(child: _AttachmentRail(files: _files)),
                  _EmojiToolButton(
                    key: const Key('community-add-image-button'),
                    label: '🖼',
                    onTap: _pickImages,
                  ),
                  const SizedBox(width: 8),
                  _EmojiToolButton(
                    key: const Key('community-add-poll-button'),
                    label: '📊',
                    onTap: () => setState(() => _showPoll = !_showPoll),
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

class _AttachmentRail extends StatelessWidget {
  final List<XFile> files;

  const _AttachmentRail({required this.files});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('community-attachment-rail'),
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.image, color: AppColors.muted),
        ),
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemCount: files.length,
      ),
    );
  }
}

class _EmojiToolButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _EmojiToolButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

class _PollPanel extends StatelessWidget {
  final TextEditingController questionCtrl;
  final List<TextEditingController> optionCtrls;

  const _PollPanel({required this.questionCtrl, required this.optionCtrls});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('community-poll-panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextField(
            controller: questionCtrl,
            decoration: const InputDecoration(
              hintText: '투표 질문',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < optionCtrls.length; i++) ...[
            TextField(
              controller: optionCtrls[i],
              decoration: InputDecoration(
                hintText: '선택지 ${i + 1}',
                border: const OutlineInputBorder(),
              ),
            ),
            if (i != optionCtrls.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
