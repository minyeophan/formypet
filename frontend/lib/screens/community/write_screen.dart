import 'package:flutter/cupertino.dart';
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
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '제목을 입력해 주세요');
      return;
    }
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
            title: title,
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
    final options = _pollOptionCtrls
        .map((ctrl) => ctrl.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (options.length < 2) return null;
    return PollDraft(question: '투표', options: options);
  }

  Future<void> _selectCategory() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    final selected = await _showCategoryPickerSheet(
      context: context,
      currentCategory: _category,
    );
    if (selected == null || !mounted) return;
    setState(() => _category = selected);
  }

  void _addPollOption() {
    setState(() {
      _pollOptionCtrls.add(TextEditingController());
    });
  }

  void _closePoll() {
    setState(() => _showPoll = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          await dismissKeyboardBeforeTransition(context);
                          if (context.mounted) {
                            context.pop();
                          }
                        },
                        child: const AppText(
                          '취소',
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: TextButton(
                        key: const Key('community-category-field'),
                        onPressed: _isLoading ? null : _selectCategory,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.text,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(
                              _communityCategoryLabel(_category),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const AppText(
                                '등록',
                                fontSize: 14,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      const AppText(
                        '제목',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          key: const Key('community-title-field'),
                          controller: _titleCtrl,
                          maxLength: 120,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                          decoration: const InputDecoration(
                            hintText: '제목을 입력해주세요',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: AppColors.muted,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: _showPoll ? 160 : 360,
                  child: Stack(
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _contentCtrl,
                        builder: (context, value, child) {
                          if (value.text.isNotEmpty) {
                            return const SizedBox.shrink();
                          }
                          return const Positioned(
                            left: 18,
                            top: 18,
                            right: 18,
                            child: Text(
                              '반려동물과 함께한 이야기, 궁금한 점, 나누고 싶은 정보를 적어주세요.',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.muted,
                                height: 1.4,
                              ),
                            ),
                          );
                        },
                      ),
                      TextField(
                        key: const Key('community-content-field'),
                        controller: _contentCtrl,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.text,
                          height: 1.45,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(18, 18, 18, 18),
                        ),
                        minLines: 14,
                        maxLines: 20,
                      ),
                    ],
                  ),
                ),
                if (_showPoll) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PollPanel(
                      optionCtrls: _pollOptionCtrls,
                      onAddOption: _addPollOption,
                      onClose: _closePoll,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: AppText(_error!, fontSize: 12, color: Colors.red),
                  ),
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
                  _ToolButton(
                    key: const Key('community-add-image-button'),
                    icon: Icons.image_outlined,
                    onTap: _pickImages,
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    key: const Key('community-add-poll-button'),
                    icon: Icons.poll_outlined,
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

Future<String?> _showCategoryPickerSheet({
  required BuildContext context,
  required String currentCategory,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _CategoryWheelSheet(currentCategory: currentCategory),
  );
}

class _CategoryWheelSheet extends StatefulWidget {
  final String currentCategory;

  const _CategoryWheelSheet({required this.currentCategory});

  @override
  State<_CategoryWheelSheet> createState() => _CategoryWheelSheetState();
}

class _CategoryWheelSheetState extends State<_CategoryWheelSheet> {
  late String _pendingCategory;

  @override
  void initState() {
    super.initState();
    _pendingCategory = widget.currentCategory;
  }

  @override
  Widget build(BuildContext context) {
    final initialIndex = kCommunityCategories.indexOf(widget.currentCategory);
    final safeInitialIndex = initialIndex < 0 ? 0 : initialIndex;

    return SafeArea(
      top: false,
      child: Container(
        key: const Key('community-category-sheet'),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const AppText(
                      '취소',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: AppText(
                        '게시판 선택',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_pendingCategory),
                    child: const AppText(
                      '완료',
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: CupertinoPicker.builder(
                key: const Key('community-category-wheel'),
                scrollController: FixedExtentScrollController(
                  initialItem: safeInitialIndex,
                ),
                itemExtent: 44,
                selectionOverlay: Center(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft.withValues(alpha: 0.78),
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                onSelectedItemChanged: (index) {
                  _pendingCategory = kCommunityCategories[index];
                },
                childCount: kCommunityCategories.length,
                itemBuilder: (context, index) {
                  final category = kCommunityCategories[index];
                  return Center(
                    child: AppText(
                      key: Key('community-category-option-$category'),
                      _communityCategoryLabel(category),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ToolButton({super.key, required this.icon, required this.onTap});

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
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
    );
  }
}

class _PollPanel extends StatelessWidget {
  final List<TextEditingController> optionCtrls;
  final VoidCallback onAddOption;
  final VoidCallback onClose;

  const _PollPanel({
    required this.optionCtrls,
    required this.onAddOption,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('community-poll-panel'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_box_outline_blank,
                size: 20,
                color: AppColors.text,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: AppText('투표', fontSize: 15, fontWeight: FontWeight.bold),
              ),
              IconButton(
                key: const Key('community-poll-close-button'),
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < optionCtrls.length; i++) ...[
            TextField(
              key: Key('community-poll-option-field-$i'),
              controller: optionCtrls[i],
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                hintText: '항목 입력',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.textSecondary),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('community-poll-add-option-button'),
              onPressed: onAddOption,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const AppText(
                '항목 추가',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const AppText(
            '* 글 등록 이후에는 투표를 수정할 수 없어요.',
            key: Key('community-poll-note'),
            fontSize: 12,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

String _communityCategoryLabel(String category) {
  return _communityCategoryLabels[category] ?? category;
}

const Map<String, String> _communityCategoryLabels = {
  'CARE': '케어',
  'FOOD': '사료/간식',
  'OUTING': '산책/외출',
  'SHOW': '자랑',
  'QUESTION': '질문',
  'FREE': '자유',
  'ADOPTION': '입양',
  'RESCUE': '구조',
  'NEWS': '소식',
  'EVENT': '이벤트',
};
