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
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/draft_exit_guard.dart';

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
  late final String? _petId = ref.read(petProvider).activePetId;
  final _service = PetLogService();
  late DateTime _entryAt = DateTime.now();

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진을 준비하지 못했어요: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장하지 못했어요. 입력은 유지됩니다. $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  String get _dateTimeLabel {
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final time =
        '${_entryAt.hour.toString().padLeft(2, '0')}:${_entryAt.minute.toString().padLeft(2, '0')}';
    return '${_entryAt.year}년 ${_entryAt.month}월 ${_entryAt.day}일 ${weekdays[_entryAt.weekday - 1]} $time';
  }

  Future<void> _showPhotoSources() => showModalBottomSheet<void>(
    context: context,
    builder: (c) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('앨범에서 선택'),
            onTap: () {
              Navigator.pop(c);
              _pick(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('카메라로 촬영'),
            onTap: () {
              Navigator.pop(c);
              _pick(ImageSource.camera);
            },
          ),
        ],
      ),
    ),
  );

  Widget _emptyPhotoPrompt() => Container(
    key: const Key('pet-log-empty-photo-prompt'),
    height: 276,
    decoration: BoxDecoration(
      color: const Color(0xFFF3FBF7),
      border: Border.all(color: const Color(0xFFE1F0E8)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 116,
          height: 92,
          child: SvgPicture.asset('assets/illustrations/pet_log_empty.svg'),
        ),
        const SizedBox(height: 8),
        const Text(
          '오늘의 사진을 골라볼까요?',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '함께한 순간을 그대로 담아주세요.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy || _requestOutcomeUnknown || _order.length >= 10
              ? null
              : _showPhotoSources,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('사진 선택'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(132, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
      appBar: AppBar(
        title: Text(widget.editing == null ? '기록 남기기' : '기록 수정'),
        leading: IconButton(
          onPressed: _busy ? null : _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: _busy || _order.isEmpty || _conflictDetected
                ? null
                : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Center(
            child: TextButton.icon(
              onPressed: _busy || _requestOutcomeUnknown
                  ? null
                  : _chooseDateTime,
              icon: const Icon(Icons.schedule_outlined, size: 16),
              label: Text(_dateTimeLabel),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: const TextStyle(fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 34),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_order.isEmpty)
            _emptyPhotoPrompt()
          else ...[
            Row(
              children: [
                Text(
                  '사진 ${_order.length}장',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _busy || _order.length >= 10
                      ? null
                      : _showPhotoSources,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('사진 추가'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _order.length; i++) _photoItem(_order[i], i),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy || _order.isEmpty || _requestOutcomeUnknown
                    ? null
                    : _editPhotos,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('사진 순서·삭제 편집'),
              ),
            ),
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
              const Icon(Icons.edit_outlined, size: 17, color: AppColors.text),
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
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            onChanged: (_) => setState(() {}),
            readOnly: _requestOutcomeUnknown,
            maxLength: 2000,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '오늘 어떤 순간이 기억에 남았나요?\n아이와 함께한 이야기를 적어주세요.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFFE8EFEB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFFE8EFEB)),
              ),
              contentPadding: EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '짧은 한마디도 소중한 기록이 돼요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 34),
          Center(
            child: Text(
              _order.isEmpty
                  ? '사진을 담고, 오늘의 기록을 저장해요'
                  : '사진 ${_order.length}장과 오늘의 기록을 저장해요',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _editPhotos() async {
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진을 준비하지 못했어요: $e')));
      }
      return const [];
    }
  }

  Future<void> _chooseDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _entryAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_entryAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _entryAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Widget _photoItem(Object item, int index) {
    final key = ValueKey(
      item is PetLogPhoto
          ? 'existing-${item.id}'
          : 'new-${(item as PreparedPhoto).filename}-$index',
    );
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 210,
              child: item is PetLogPhoto
                  ? AuthenticatedNetworkImage(
                      url: item.url,
                      fallback: const ColoredBox(color: AppColors.surfaceSoft),
                      height: 210,
                      fit: BoxFit.contain,
                    )
                  : Image.memory(
                      (item as PreparedPhoto).bytes,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
          Text('${index + 1}'),
        ],
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
      appBar: AppBar(
        title: const Text('사진 편집'),
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사진 ${_photos.length}장',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '오른쪽 손잡이를 길게 눌러 순서를 바꿔요.\n첫 번째 사진이 목록의 대표사진이 돼요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _photos.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '첨부한 사진이 없어요.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '기록에 담을 사진을 한 장 이상 추가해주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: FilledButton(
                              onPressed: widget.onAddPhotos == null
                                  ? null
                                  : _addPhotos,
                              child: const Text('사진 추가'),
                            ),
                          ),
                        ],
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
                              fit: BoxFit.cover,
                            )
                          : Image.memory(
                              (photo as PreparedPhoto).bytes,
                              fit: BoxFit.cover,
                            );
                      return Container(
                        key: ValueKey(
                          photo is PetLogPhoto
                              ? 'photo-${photo.id}'
                              : 'draft-${identityHashCode(photo)}',
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
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
                                      top: 4,
                                      right: 4,
                                      child: Material(
                                        color: Colors.white,
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          tooltip: '사진 삭제',
                                          visualDensity: VisualDensity.compact,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                width: 30,
                                                height: 30,
                                              ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _remove(index),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: AppColors.textSecondary,
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
                                  const SizedBox(height: 6),
                                  const Text(
                                    '원본 비율 유지',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
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
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: AppColors.muted,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0F2F1))),
              ),
              child: Column(
                children: [
                  const Text(
                    '완료하면 작성 화면에 반영돼요. 기록의 저장 버튼을 눌러야 최종 저장돼요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                        foregroundColor: Colors.white,
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
