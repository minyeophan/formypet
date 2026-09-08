import '../../widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../providers/community_provider.dart';
import '../../models/post.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import 'community_constants.dart';

class WriteScreen extends ConsumerStatefulWidget {
  const WriteScreen({super.key, this.editingPost});
  final Post? editingPost;

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
  void initState() {
    super.initState();
    final post = widget.editingPost;
    if (post != null) {
      _titleCtrl.text = post.title ?? '';
      _contentCtrl.text = post.content;
      _category = post.category;
    }
  }

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
    if (_isLoading) return;
    if (_files.length >= 5) {
      _showImageLimit();
      return;
    }
    try {
      final picked = await _imagePicker.pickMultiImage();
      if (!mounted || _isLoading || picked.isEmpty) return;
      final remaining = 5 - _files.length;
      setState(() => _files.addAll(picked.take(remaining)));
      if (picked.length > remaining) _showImageLimit();
    } catch (_) {
      if (!mounted || _isLoading) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('사진을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
    }
  }

  void _showImageLimit() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('사진은 최대 5장까지 첨부할 수 있어요.')));
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '제목을 입력해 주세요');
      return;
    }
    if (content.isEmpty) {
      setState(() => _error = '내용을 입력해 주세요');
      return;
    }
    final files = List<XFile>.unmodifiable(_files);
    final poll = _buildPollDraft();
    if (poll != null && (poll.options.length < 2 || poll.options.length > 5)) {
      const message = '투표 선택지는 빈 항목을 제외하고 2~5개 입력해 주세요.';
      setState(() => _error = message);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(message)));
      return;
    }
    final category = _category;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await dismissKeyboardBeforeTransition(context);
      if (!mounted) return;
      final notifier = ref.read(communityProvider.notifier);
      if (widget.editingPost == null) {
        await notifier.createPost(
          content: content,
          title: title,
          category: category,
          files: files,
          poll: poll,
        );
      } else {
        await notifier.updatePost(
          widget.editingPost!.id,
          title: title,
          content: content,
          category: category,
        );
      }
      if (mounted) await _goBackToCommunity();
    } catch (_) {
      if (mounted) {
        setState(() => _error = '글을 등록하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
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
    if (_isLoading || _pollOptionCtrls.length >= 5) return;
    setState(() {
      _pollOptionCtrls.add(TextEditingController());
    });
  }

  void _closePoll() {
    setState(() => _showPoll = false);
  }

  Future<void> _goBackToCommunity() async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/community');
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
                        onPressed: _goBackToCommunity,
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
                            const AppIcon(Icons.keyboard_arrow_down, size: 18),
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
                          maxLength: 30,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
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
                            filled: false,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
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
                        filled: false,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(18, 18, 18, 18),
                      ),
                      minLines: _showPoll ? 5 : 10,
                      maxLines: null,
                    ),
                  ],
                ),
                if (_showPoll) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PollPanel(
                      enabled: !_isLoading,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.editingPost != null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: AppText(
                        '사진과 투표는 수정할 수 없어요. 기존 첨부 내용은 유지돼요.',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (widget.editingPost == null ||
                      widget.editingPost!.imageUrls.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: _AttachmentRail(
                            files: _files,
                            imageUrls:
                                widget.editingPost?.imageUrls ?? const [],
                            onRemove: _isLoading
                                ? null
                                : (file) {
                                    if (_isLoading) return;
                                    setState(() => _files.remove(file));
                                  },
                          ),
                        ),
                        if (widget.editingPost == null) ...[
                          _ToolButton(
                            key: const Key('community-add-image-button'),
                            icon: Icons.image_outlined,
                            onTap: _isLoading ? null : _pickImages,
                          ),
                          const SizedBox(width: 8),
                          _ToolButton(
                            key: const Key('community-add-poll-button'),
                            icon: Icons.poll_outlined,
                            onTap: _isLoading
                                ? null
                                : () => setState(() => _showPoll = !_showPoll),
                          ),
                        ],
                      ],
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
  final List<String> imageUrls;
  final ValueChanged<XFile>? onRemove;

  const _AttachmentRail({
    required this.files,
    required this.imageUrls,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('community-attachment-rail'),
      height: files.isEmpty && imageUrls.isEmpty ? 48 : 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          if (index < files.length) {
            final file = files[index];
            return _SelectedAttachment(
              key: ObjectKey(file),
              file: file,
              index: index,
              onRemove: onRemove == null ? null : () => onRemove!(file),
            );
          }
          return Semantics(
            label: '기존 사진 ${index - files.length + 1}',
            image: true,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AuthenticatedNetworkImage(
                  url: imageUrls[index - files.length],
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  fallback: const _AttachmentUnavailable(),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemCount: files.length + imageUrls.length,
      ),
    );
  }
}

class _SelectedAttachment extends StatefulWidget {
  final XFile file;
  final int index;
  final VoidCallback? onRemove;

  const _SelectedAttachment({
    super.key,
    required this.file,
    required this.index,
    required this.onRemove,
  });

  @override
  State<_SelectedAttachment> createState() => _SelectedAttachmentState();
}

class _SelectedAttachmentState extends State<_SelectedAttachment> {
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  Future<void> _preview(Uint8List bytes) async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const _AttachmentUnavailable(),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: FutureBuilder<Uint8List>(
              future: _bytes,
              builder: (context, snapshot) => Semantics(
                label: '사진 ${widget.index + 1} 미리보기',
                button: snapshot.hasData,
                enabled: widget.onRemove != null,
                child: InkWell(
                  onTap: snapshot.hasData && widget.onRemove != null
                      ? () => _preview(snapshot.data!)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: snapshot.hasData
                          ? Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) =>
                                  const _AttachmentUnavailable(),
                            )
                          : snapshot.hasError
                          ? const _AttachmentUnavailable()
                          : const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: '사진 ${widget.index + 1} 삭제',
              onPressed: widget.onRemove,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: const EdgeInsets.all(10),
              icon: const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(Icons.close, size: 24, color: AppColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentUnavailable extends StatelessWidget {
  const _AttachmentUnavailable();

  @override
  Widget build(BuildContext context) => Semantics(
    label: '사진 미리보기를 불러올 수 없어요',
    child: const Center(
      child: AppIcon(Icons.image_not_supported, color: AppColors.muted),
    ),
  );
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

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
        child: AppIcon(
          icon,
          color: onTap == null ? AppColors.muted : AppColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}

class _PollPanel extends StatelessWidget {
  final bool enabled;
  final List<TextEditingController> optionCtrls;
  final VoidCallback onAddOption;
  final VoidCallback onClose;

  const _PollPanel({
    required this.enabled,
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
              const AppIcon(
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
                onPressed: enabled ? onClose : null,
                visualDensity: VisualDensity.compact,
                icon: const AppIcon(Icons.close, size: 20),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < optionCtrls.length; i++) ...[
            TextField(
              key: Key('community-poll-option-field-$i'),
              enabled: enabled,
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
              onPressed: enabled && optionCtrls.length < 5 ? onAddOption : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const AppIcon(Icons.add, size: 18),
              label: const AppText(
                '항목 추가',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const AppText(
            '* 선택지는 2~5개 입력해 주세요. 글 등록 이후에는 투표를 수정할 수 없어요.',
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
