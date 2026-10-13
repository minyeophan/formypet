import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../providers/pet_provider.dart';
import '../../services/photo_preparation.dart';
import '../../services/pet_log_service.dart';
import '../../models/pet_log.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_confirmation_sheet.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_more_button.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/draft_exit_guard.dart';
import '../../widgets/record_inputs/record_inputs.dart';

class PetLogCreateScreen extends ConsumerStatefulWidget {
  const PetLogCreateScreen({super.key, this.editing});
  final PetLog? editing;
  @override
  ConsumerState<PetLogCreateScreen> createState() => _PetLogCreateScreenState();
}

class _PetLogCreateScreenState extends ConsumerState<PetLogCreateScreen>
    with DraftExitGuardMixin<PetLogCreateScreen> {
  final _picker = ImagePicker();
  final _text = TextEditingController();
  final List<PreparedPhoto> _photos = [];
  final List<Object> _order = [];
  final Map<PreparedPhoto, String> _uploadKeys = {};
  final Map<PreparedPhoto, int> _uploadedIds = {};
  String? _saveKey;
  String? _pickerRecoveryMessage;
  bool _pendingDraftWork = false;
  bool _requestOutcomeUnknown = false;
  bool _conflictDetected = false;
  bool _loadingConflict = false;
  String? _conflictError;
  PetLog? _conflictingLatest;
  late String _baseline;
  bool _busy = false;
  bool _editActionsOpen = false;
  late final String? _petId = ref.read(petProvider).activePetId;
  final _service = PetLogService();
  late DateTime _entryAt = DateTime.now();
  // Pet-log API still requires a time; new date-only entries use midnight.
  void _resetNewEntryTimeToMidnight() {
    final now = DateTime.now();
    _entryAt = DateTime(now.year, now.month, now.day);
  }

  String get _draft => jsonEncode({
    'at': _entryAt.toIso8601String(),
    'note': _text.text,
    'photos': _order
        .map(
          (item) => item is PetLogPhoto
              ? 'existing:${item.id}'
              : 'new:${identityHashCode(item)}',
        )
        .toList(),
  });
  @override
  bool get hasUnsavedChanges => _draft != _baseline;
  @override
  bool get isDraftBusy => _busy;
  @override
  bool get hasPendingDraftWork =>
      _pendingDraftWork || _requestOutcomeUnknown || _conflictDetected;
  @override
  String get draftExitMessage => _requestOutcomeUnknown
      ? '저장 여부를 확인하지 못했어요. 나가더라도 기록이 저장되어 있을 수 있어요.'
      : _conflictDetected
      ? '다른 곳에서 기록이 수정됐어요. 최신 기록을 확인하거나 현재 변경을 취소할 수 있어요.'
      : _pendingDraftWork
      ? '기록은 아직 저장되지 않았어요. 업로드가 끝나지 않은 사진은 기록에 포함되지 않아요.'
      : '저장하지 않은 변경사항은 사라져요.';
  @override
  void onDraftExitConfirmed() {
    final petId = _petId;
    if (_requestOutcomeUnknown && petId != null) {
      unawaited(_reconcileList(petId));
    }
  }

  Future<void> _reconcileList(String petId) async {
    PetLogService.notifyChanged();
    Future<void>.delayed(
      const Duration(seconds: 2),
      PetLogService.notifyChanged,
    );
    try {
      await _service.list(petId);
    } catch (_) {
      /* The timeline retries when it becomes visible. */
    }
  }

  @override
  void initState() {
    super.initState();
    final log = widget.editing;
    if (log != null) {
      _entryAt = DateTime.parse('${log.date}T${log.time}');
      _text.text = log.note ?? '';
      _order.addAll(log.photos);
    } else {
      _resetNewEntryTimeToMidnight();
    }
    _baseline = _draft;
    unawaited(_recoverLostPickerData());
  }

  Future<void> _recoverLostPickerData() async {
    if (kIsWeb) return;
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty || !mounted) return;
      final petId = _petId;
      if (petId == null || petId != ref.read(petProvider).activePetId) return;
      final files = lost.files;
      if (files == null || files.isEmpty) {
        setState(() => _pickerRecoveryMessage = '사진을 복구하지 못했어요. 다시 선택해 주세요.');
        return;
      }
      final remaining = 10 - _order.length;
      if (files.length > remaining) {
        setState(
          () =>
              _pickerRecoveryMessage = '복구된 사진이 남은 등록 수보다 많아요. 사진을 다시 선택해 주세요.',
        );
        return;
      }
      final prepared = <PreparedPhoto>[];
      for (final file in files) {
        prepared.add(await preparePhoto(file));
      }
      if (!mounted || petId != ref.read(petProvider).activePetId) return;
      setState(() {
        _photos.addAll(prepared);
        _order.addAll(prepared);
        _pickerRecoveryMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _pickerRecoveryMessage = '사진을 복구하지 못했어요. 다시 선택해 주세요.');
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy || _requestOutcomeUnknown) return;
    try {
      final prepared = <PreparedPhoto>[];
      if (source == ImageSource.gallery) {
        final remaining = 10 - _order.length;
        final files = await _picker.pickMultiImage(limit: remaining);
        if (files.length > remaining) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('사진은 최대 10장까지예요. $remaining장만 더 선택할 수 있어요.'),
              ),
            );
          }
          return;
        }
        for (final file in files) {
          prepared.add(await preparePhoto(file));
        }
      } else {
        final file = await _picker.pickImage(source: source);
        if (file != null && _order.length < 10) {
          prepared.add(await preparePhoto(file));
        }
      }
      if (mounted && prepared.isNotEmpty) {
        setState(() {
          _photos.addAll(prepared);
          _order.addAll(prepared);
        });
      }
    } on PlatformException catch (e) {
      final message = switch (e.code) {
        'camera_access_denied' => '카메라 권한이 없어 촬영할 수 없어요. 설정에서 카메라 접근을 허용해 주세요.',
        'photo_access_denied' =>
          '사진 보관함 권한이 없어 사진을 선택할 수 없어요. 설정에서 접근을 허용해 주세요.',
        'camera_unavailable' ||
        'no_available_camera' => '이 기기에서 카메라를 사용할 수 없어요.',
        _ => '사진 선택을 완료하지 못했어요. 다시 시도해 주세요.',
      };
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PhotoPreparationException
                  ? e.message
                  : '사진을 준비하지 못했어요. 다시 시도해 주세요.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final petId = _petId;
    final editing = widget.editing;
    if (petId == null || _order.isEmpty) return;
    if (editing != null && !hasUnsavedChanges) {
      await allowDraftExit();
      if (!mounted) return;
      final latest = _conflictingLatest;
      if (latest != null) {
        context.go('/pet-log/${latest.id}', extra: latest);
      } else {
        context.pop();
      }
      return;
    }
    if (_conflictDetected) return;
    setState(() => _busy = true);
    final ids = <int>[];
    var finalRequestStarted = false;
    try {
      final activeDraftPhotos = _photos
          .where((photo) => _order.contains(photo))
          .toList(growable: false);
      for (final p in activeDraftPhotos) {
        _ensurePetCurrent(petId);
        _pendingDraftWork = true;
        _uploadedIds[p] ??= await _service.upload(
          petId,
          p.bytes,
          p.filename,
          _uploadKeys.putIfAbsent(p, () => 'petlog-media-${_newKey()}'),
        );
      }
      for (final item in _order) {
        if (item is PetLogPhoto) {
          ids.add(int.parse(item.id));
        } else if (item is PreparedPhoto) {
          ids.add(_uploadedIds[item]!);
        }
      }
      final now = _entryAt;
      _ensurePetCurrent(petId);
      finalRequestStarted = true;
      final log = editing == null
          ? await _service.create(
              petId,
              now,
              _text.text.trim().isEmpty ? null : _text.text.trim(),
              ids,
              _saveKey ??= 'petlog-create-${_newKey()}',
            )
          : await _service.update(
              petId,
              editing.id,
              now,
              _text.text.trim().isEmpty ? null : _text.text.trim(),
              ids,
              editing.version,
              _saveKey ??= 'petlog-update-${_newKey()}',
            );
      if (!mounted) return;
      _pendingDraftWork = false;
      _requestOutcomeUnknown = false;
      PetLogService.notifyChanged();
      await allowDraftExit();
      if (!mounted) return;
      context.go('/pet-log/${log.id}', extra: log);
    } catch (e) {
      if (finalRequestStarted &&
          e is DioException &&
          (e.response == null || (e.response!.statusCode ?? 0) >= 500)) {
        _requestOutcomeUnknown = true;
      }
      if (e is DioException &&
          e.response != null &&
          (e.response!.statusCode ?? 0) < 500) {
        _saveKey = null;
      }
      final isConflict =
          editing != null && e is DioException && e.response?.statusCode == 409;
      if (isConflict && mounted) {
        setState(() => _conflictDetected = true);
        await _loadConflict(petId, editing.id);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장하지 못했어요. 입력은 유지됩니다. 연결을 확인하고 다시 시도해 주세요.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteEditing() async {
    final log = widget.editing;
    if (log == null || _busy) return;
    final confirmed = await showAppConfirmationSheet(
      context,
      title: '기록을 삭제할까요?',
      message: '삭제한 기록은 다시 복구할 수 없어요.',
      confirmLabel: '삭제',
      confirmKey: const Key('pet-log-edit-delete-confirm'),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.delete(
        log.petId,
        log.id,
        log.version,
        'petlog-edit-delete-${log.id}-${log.version}',
      );
      PetLogService.notifyChanged();
      if (mounted) context.go('/pet-log');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록을 삭제하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showEditActions() async {
    if (widget.editing == null || _busy) return;
    String? selectedAction;
    setState(() => _editActionsOpen = true);
    try {
      await showAppActionSheet(
        context,
        presentation: AppActionSheetPresentation.compactMenu,
        title: null,
        closeLabel: null,
        actions: [
          AppActionSheetItem(
            key: const Key('pet-log-edit-menu-save'),
            label: '저장',
            buttonStyle: AppActionSheetButtonStyle.primary,
            onTap: () => selectedAction = 'save',
          ),
          AppActionSheetItem(
            key: const Key('pet-log-edit-menu-delete'),
            label: '삭제',
            buttonStyle: AppActionSheetButtonStyle.destructive,
            onTap: () => selectedAction = 'delete',
          ),
          AppActionSheetItem(
            key: const Key('pet-log-edit-menu-cancel'),
            label: '취소',
            buttonStyle: AppActionSheetButtonStyle.secondary,
          ),
        ],
      );
    } finally {
      if (mounted) setState(() => _editActionsOpen = false);
    }
    if (!mounted) return;
    if (selectedAction == 'save') await _save();
    if (selectedAction == 'delete') await _deleteEditing();
  }

  Future<void> _loadConflict(String petId, String recordId) async {
    setState(() {
      _loadingConflict = true;
      _conflictError = null;
    });
    try {
      final latest = await _service.get(petId, recordId);
      if (!mounted || ref.read(petProvider).activePetId != petId) return;
      setState(() => _conflictingLatest = latest);
    } catch (_) {
      if (mounted) setState(() => _conflictError = '최신 기록을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _loadingConflict = false);
    }
  }

  String _newKey() => DateTime.now().microsecondsSinceEpoch.toString();
  void _ensurePetCurrent(String petId) {
    if (ref.read(petProvider).activePetId != petId) {
      throw StateError('아이를 바꿨어요. 현재 아이를 확인한 뒤 다시 저장해 주세요.');
    }
  }

  String get _dateLabel {
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return '${_entryAt.year}년 ${_entryAt.month}월 ${_entryAt.day}일 ${weekdays[_entryAt.weekday - 1]}';
  }

  Future<ImageSource?> _choosePhotoSource() async {
    ImageSource? source;
    await showAppActionSheet(
      context,
      title: '사진 추가',
      closeLabel: '취소',
      actions: [
        AppActionSheetItem(
          key: const Key('pet-log-photo-source-gallery'),
          label: '사진 보관함',
          description: '저장된 사진에서 선택',
          icon: Icons.photo_library_outlined,
          showChevron: true,
          accented: true,
          onTap: () => source = ImageSource.gallery,
        ),
        AppActionSheetItem(
          key: const Key('pet-log-photo-source-camera'),
          label: '카메라',
          description: '지금 촬영해서 추가',
          icon: Icons.photo_camera_outlined,
          showChevron: true,
          accented: true,
          onTap: () => source = ImageSource.camera,
        ),
      ],
    );
    return source;
  }

  Future<void> _showPhotoSources() async {
    final source = await _choosePhotoSource();
    if (source != null && mounted) await _pick(source);
  }

  Widget _emptyPhotoPrompt() => Container(
    key: const Key('pet-log-empty-photo-prompt'),
    height: 276,
    decoration: BoxDecoration(
      color: const Color(0xFFF3FAF6),
      border: Border.all(color: const Color(0xFFDCEEE4)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          width: 128,
          height: 100,
          child: SvgPicture.asset('assets/illustrations/pet_log_empty.svg'),
        ),
        const SizedBox(height: 7),
        const Text(
          '오늘의 사진을 골라볼까요?',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            height: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '함께한 순간을 그대로 담아주세요.',
          style: TextStyle(color: Color(0xFF697771), fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 27),
        SizedBox(
          width: 150,
          height: 44,
          child: FilledButton(
            onPressed: _busy || _requestOutcomeUnknown || _order.length >= 10
                ? null
                : _showPhotoSources,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size(150, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('사진 추가'),
          ),
        ),
      ],
    ),
  );

  Future<void> _goBack() async {
    if (!await confirmDraftExit() || !mounted) return;
    final latest = _conflictDetected ? _conflictingLatest : null;
    if (latest != null) {
      context.go('/pet-log/${latest.id}', extra: latest);
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/pet-log');
  }

  @override
  Widget build(BuildContext context) => protectDraft(
    onExit: _goBack,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: widget.editing == null ? '기록 남기기' : '기록 수정',
        showBackButton: true,
        onBack: _goBack,
        leadingWidth: 55,
        actions: [
          if (widget.editing == null && !_editActionsOpen)
            TextButton(
              onPressed: _busy || _order.isEmpty || _conflictDetected
                  ? null
                  : _save,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF253C39),
                disabledForegroundColor: AppColors.muted,
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장'),
            ),
          if (widget.editing != null)
            AppMoreButton.plain(
              key: const Key('pet-log-edit-more'),
              tooltip: '수정 작업',
              onPressed: _busy ? null : _showEditActions,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        children: [
          if (widget.editing == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy || _requestOutcomeUnknown ? null : _chooseDate,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: const TextStyle(fontSize: 13),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 34),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(_dateLabel),
              ),
            ),
          if (widget.editing == null) const SizedBox(height: 8),
          if (_order.isEmpty)
            _emptyPhotoPrompt()
          else ...[
            for (var i = 0; i < _order.length; i++) _photoItem(_order[i], i),
          ],
          if (_pickerRecoveryMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _pickerRecoveryMessage!,
                style: const TextStyle(color: Colors.deepOrange),
              ),
            ),
          if (_conflictDetected)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '기록이 다른 곳에서 수정됐어요. 작성 중인 내용은 유지했어요.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (_loadingConflict)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(),
                    ),
                  if (_conflictError != null)
                    TextButton(
                      onPressed: () =>
                          _loadConflict(_petId!, widget.editing!.id),
                      child: const Text('최신 기록 다시 확인'),
                    ),
                  if (_conflictingLatest case final latest?) ...[
                    TextButton(
                      onPressed: () =>
                          context.push('/pet-log/${latest.id}', extra: latest),
                      child: const Text('최신 기록 보기'),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.go('/pet-log/${latest.id}', extra: latest),
                      child: const Text('내 변경 취소'),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Text(
                widget.editing == null ? '오늘의 이야기' : '이날의 이야기',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          SizedBox(
            height: 114,
            child: TextField(
              controller: _text,
              onChanged: (_) => setState(() {}),
              readOnly: _requestOutcomeUnknown,
              maxLength: 2000,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                hintText: '오늘 어떤 순간이 기억에 남았나요?\n아이와 함께한 이야기를 적어주세요.',
                hintStyle: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                contentPadding: EdgeInsets.fromLTRB(14, 16, 14, 16),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            '짧은 한마디도 소중한 기록이 돼요.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
      bottomNavigationBar: widget.editing != null
          ? SafeArea(
              top: false,
              child: Container(
                key: const Key('pet-log-edit-footer'),
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      key: const Key('pet-log-edit-footer-photo-edit'),
                      onPressed: _busy || _requestOutcomeUnknown
                          ? null
                          : _editPhotos,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size(107, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('사진 편집'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const Key('pet-log-edit-footer-date-change'),
                      onPressed: _busy || _requestOutcomeUnknown
                          ? null
                          : _chooseDate,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.surfaceSoft,
                        foregroundColor: AppColors.text,
                        minimumSize: const Size(107, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('날짜 변경'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: Container(
                key: const Key('pet-log-create-footer'),
                width: double.infinity,
                height: 86,
                padding: const EdgeInsets.only(bottom: 10),
                alignment: Alignment.center,
                child: Text(
                  _order.isEmpty
                      ? '사진을 담고, 오늘의 기록을 저장해요'
                      : '사진 ${_order.length}장과 오늘의 기록을 저장해요',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ),
            ),
    ),
  );

  Future<void> _editPhotos() async {
    if (_busy || _requestOutcomeUnknown) return;
    final result = await Navigator.of(context).push<List<Object>>(
      MaterialPageRoute(
        builder: (_) => PetLogPhotoEditScreen(
          photos: _order,
          onAddPhotos: _pickForPhotoEditor,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _order
        ..clear()
        ..addAll(result);
      final retainedDraftPhotos = result.whereType<PreparedPhoto>().toSet();
      final removedDraftPhotos = _photos
          .where((photo) => !retainedDraftPhotos.contains(photo))
          .toList(growable: false);
      _photos.removeWhere((photo) => !retainedDraftPhotos.contains(photo));
      for (final photo in removedDraftPhotos) {
        _uploadKeys.remove(photo);
        _uploadedIds.remove(photo);
      }
      _saveKey = null;
    });
  }

  Future<List<Object>> _pickForPhotoEditor(int availableSlots) async {
    if (_busy || _requestOutcomeUnknown || availableSlots <= 0) return const [];
    final source = await _choosePhotoSource();
    if (source == null || !mounted) return const [];
    try {
      final files = source == ImageSource.gallery
          ? await _picker.pickMultiImage(limit: availableSlots)
          : await _picker
                .pickImage(source: source)
                .then((file) => file == null ? <XFile>[] : <XFile>[file]);
      if (!mounted) return const [];
      if (files.length > availableSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진은 최대 10장까지예요. $availableSlots장만 더 선택할 수 있어요.'),
          ),
        );
        return const [];
      }
      final prepared = <Object>[];
      for (final file in files) {
        prepared.add(await preparePhoto(file));
      }
      return prepared;
    } on PlatformException catch (e) {
      final message = switch (e.code) {
        'camera_access_denied' => '카메라 권한이 없어 촬영할 수 없어요. 설정에서 카메라 접근을 허용해 주세요.',
        'photo_access_denied' =>
          '사진 보관함 권한이 없어 사진을 선택할 수 없어요. 설정에서 접근을 허용해 주세요.',
        'camera_unavailable' ||
        'no_available_camera' => '이 기기에서 카메라를 사용할 수 없어요.',
        _ => '사진 선택을 완료하지 못했어요. 다시 시도해 주세요.',
      };
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return const [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PhotoPreparationException
                  ? e.message
                  : '사진을 준비하지 못했어요. 다시 시도해 주세요.',
            ),
          ),
        );
      }
      return const [];
    }
  }

  Future<void> _chooseDate() async {
    if (_busy || _requestOutcomeUnknown) return;
    final date = await showRecordDatePickerSheet(
      context,
      initialDate: _entryAt,
    );
    if (date == null || !mounted) return;
    setState(
      () => _entryAt = DateTime(
        date.year,
        date.month,
        date.day,
        _entryAt.hour,
        _entryAt.minute,
      ),
    );
  }

  Widget _photoItem(Object item, int index) {
    final key = ValueKey(
      item is PetLogPhoto
          ? 'existing-${item.id}'
          : 'new-${(item as PreparedPhoto).filename}-$index',
    );
    final width = item is PetLogPhoto
        ? item.width
        : (item as PreparedPhoto).width;
    final height = item is PetLogPhoto
        ? item.height
        : (item as PreparedPhoto).height;
    final aspectRatio = width > 0 && height > 0 ? width / height : 1.0;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: item is PetLogPhoto
            ? AuthenticatedNetworkImage(
                url: item.url,
                fallback: const ColoredBox(color: AppColors.surfaceSoft),
                fit: BoxFit.contain,
              )
            : Image.memory((item as PreparedPhoto).bytes, fit: BoxFit.contain),
      ),
    );
  }
}

class PetLogPhotoEditScreen extends StatefulWidget {
  const PetLogPhotoEditScreen({
    super.key,
    required this.photos,
    this.onAddPhotos,
  });
  final List<Object> photos;
  final Future<List<Object>> Function(int availableSlots)? onAddPhotos;
  @override
  State<PetLogPhotoEditScreen> createState() => _PetLogPhotoEditScreenState();
}

class _PetLogPhotoEditScreenState extends State<PetLogPhotoEditScreen>
    with DraftExitGuardMixin<PetLogPhotoEditScreen> {
  late final List<Object> _photos = List<Object>.of(widget.photos);
  late final List<int> _baseline = widget.photos.map(identityHashCode).toList();
  @override
  bool get hasUnsavedChanges =>
      !listEquals(_photos.map(identityHashCode).toList(), _baseline);
  @override
  bool get isDraftBusy => false;
  @override
  bool get hasPendingDraftWork => false;

  Future<void> _goBack() async {
    if (!await confirmDraftExit() || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addPhotos() async {
    final callback = widget.onAddPhotos;
    if (callback == null || _photos.length >= 10) return;
    final additions = await callback(10 - _photos.length);
    if (!mounted || additions.isEmpty) return;
    setState(() => _photos.addAll(additions));
  }

  void _remove(int index) {
    setState(() => _photos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) => protectDraft(
    onExit: _goBack,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '사진 편집',
        showBackButton: true,
        onBack: _goBack,
        leadingWidth: 55,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _photos.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 158),
                      child: const Text(
                        '첨부한 사진이 없어요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemCount: _photos.length,
                    onReorderItem: (oldIndex, newIndex) => setState(
                      () =>
                          _photos.insert(newIndex, _photos.removeAt(oldIndex)),
                    ),
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      final image = photo is PetLogPhoto
                          ? AuthenticatedNetworkImage(
                              url: photo.url,
                              fallback: const ColoredBox(
                                color: AppColors.surfaceSoft,
                              ),
                              fit: BoxFit.contain,
                            )
                          : Image.memory(
                              (photo as PreparedPhoto).bytes,
                              fit: BoxFit.contain,
                            );
                      return Container(
                        key: ValueKey(
                          photo is PetLogPhoto
                              ? 'photo-${photo.id}'
                              : 'draft-${identityHashCode(photo)}',
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                key: const Key('pet-log-photo-edit-thumbnail'),
                                width: 124,
                                height: 124,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const ColoredBox(
                                      color: AppColors.surfaceSoft,
                                    ),
                                    image,
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Material(
                                        color: Colors.transparent,
                                        shape: const CircleBorder(),
                                        child: Tooltip(
                                          message: '사진 삭제',
                                          child: Semantics(
                                            button: true,
                                            label: '사진 삭제',
                                            child: GestureDetector(
                                              key: Key(
                                                'pet-log-photo-remove-hit-target-${photo is PetLogPhoto ? photo.id : identityHashCode(photo)}',
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _remove(index),
                                              child: SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: Stack(
                                                  children: [
                                                    Positioned(
                                                      left: 14,
                                                      top: 8,
                                                      child: SizedBox(
                                                        key: Key(
                                                          'pet-log-photo-remove-visual-${photo is PetLogPhoto ? photo.id : identityHashCode(photo)}',
                                                        ),
                                                        width: 18,
                                                        height: 18,
                                                        child: DecoratedBox(
                                                          decoration: const BoxDecoration(
                                                            color: Colors.white,
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.fromBorderSide(
                                                              BorderSide(
                                                                color: AppColors
                                                                    .border,
                                                              ),
                                                            ),
                                                          ),
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.close,
                                                              size: 12,
                                                              color: AppColors
                                                                  .textSecondary,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    index == 0 ? '대표사진' : '사진 ${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              customSemanticsActions: {
                                if (index > 0)
                                  CustomSemanticsAction(
                                    label: '사진 ${index + 1} 앞으로 이동',
                                  ): () => setState(() {
                                    final moved = _photos.removeAt(index);
                                    _photos.insert(index - 1, moved);
                                  }),
                                if (index < _photos.length - 1)
                                  CustomSemanticsAction(
                                    label: '사진 ${index + 1} 뒤로 이동',
                                  ): () => setState(() {
                                    final moved = _photos.removeAt(index);
                                    _photos.insert(index + 1, moved);
                                  }),
                              },
                              child: ReorderableDragStartListener(
                                index: index,
                                child: SizedBox(
                                  key: Key(
                                    'pet-log-photo-reorder-hit-target-$index',
                                  ),
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (
                                          var line = 0;
                                          line < 3;
                                          line++
                                        ) ...[
                                          Container(
                                            key: Key(
                                              'pet-log-photo-reorder-line-$index-$line',
                                            ),
                                            width: 18,
                                            height: 1.5,
                                            decoration: BoxDecoration(
                                              color: AppColors.muted,
                                              borderRadius:
                                                  BorderRadius.circular(1),
                                            ),
                                          ),
                                          if (line < 2)
                                            const SizedBox(height: 5.5),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0F2F1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const Key('pet-log-photo-add'),
                      onPressed:
                          widget.onAddPhotos == null || _photos.length >= 10
                          ? null
                          : _addPhotos,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor: AppColors.surfaceSoft,
                        disabledForegroundColor: AppColors.muted,
                      ),
                      child: const Text('사진 추가'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _photos.isEmpty
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              await allowDraftExit();
                              if (!mounted) return;
                              navigator.pop(List<Object>.unmodifiable(_photos));
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor: AppColors.surfaceSoft,
                        disabledForegroundColor: AppColors.muted,
                      ),
                      child: const Text('완료'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
