import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        padding: const EdgeInsets.all(20),
        children: [
          TextButton.icon(
            onPressed: _busy || _requestOutcomeUnknown ? null : _chooseDateTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              '${_entryAt.year}년 ${_entryAt.month}월 ${_entryAt.day}일 ${_entryAt.hour.toString().padLeft(2, '0')}:${_entryAt.minute.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('${_order.length}/10장'),
              const Spacer(),
              TextButton(
                onPressed: _busy || _order.length >= 10
                    ? null
                    : () => showModalBottomSheet(
                        context: context,
                        builder: (c) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.photo_library_outlined,
                                ),
                                title: const Text('앨범에서 선택'),
                                onTap: () {
                                  Navigator.pop(c);
                                  _pick(ImageSource.gallery);
                                },
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.photo_camera_outlined,
                                ),
                                title: const Text('카메라로 촬영'),
                                onTap: () {
                                  Navigator.pop(c);
                                  _pick(ImageSource.camera);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                child: const Text('사진 추가'),
              ),
            ],
          ),
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy || _order.isEmpty || _requestOutcomeUnknown
                  ? null
                  : _editPhotos,
              icon: const Icon(Icons.tune),
              label: const Text('사진 순서·삭제 편집'),
            ),
          ),
          for (var i = 0; i < _order.length; i++) _photoItem(_order[i], i),
          TextField(
            controller: _text,
            onChanged: (_) => setState(() {}),
            readOnly: _requestOutcomeUnknown,
            maxLength: 2000,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '그날의 이야기를 남겨보세요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy || _order.isEmpty || _conflictDetected
                ? null
                : _save,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(_busy ? '저장 중' : '기록 저장'),
          ),
        ],
      ),
    ),
  );

  Future<void> _editPhotos() async {
    final result = await Navigator.of(context).push<List<Object>>(
      MaterialPageRoute(builder: (_) => PetLogPhotoEditScreen(photos: _order)),
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
  const PetLogPhotoEditScreen({super.key, required this.photos});
  final List<Object> photos;
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

  void _remove(int index) {
    if (_photos.length == 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기록에는 사진이 한 장 이상 필요해요.')));
      return;
    }
    setState(() => _photos.removeAt(index));
  }

  @override
  Widget build(BuildContext context) => protectDraft(
    onExit: _goBack,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('사진 순서 편집'),
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await allowDraftExit();
              if (!mounted) return;
              navigator.pop(List<Object>.unmodifiable(_photos));
            },
            child: const Text('완료'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: _photos.length,
        onReorderItem: (oldIndex, newIndex) => setState(
          () => _photos.insert(newIndex, _photos.removeAt(oldIndex)),
        ),
        itemBuilder: (context, index) {
          final photo = _photos[index];
          final image = photo is PetLogPhoto
              ? AuthenticatedNetworkImage(
                  url: photo.url,
                  fallback: const ColoredBox(color: AppColors.surfaceSoft),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: SizedBox(height: 210, child: image)),
                IconButton(
                  tooltip: '사진 ${index + 1} 이전으로 이동',
                  onPressed: index == 0
                      ? null
                      : () => setState(() {
                          final photo = _photos.removeAt(index);
                          _photos.insert(index - 1, photo);
                        }),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: '사진 ${index + 1} 다음으로 이동',
                  onPressed: index == _photos.length - 1
                      ? null
                      : () => setState(() {
                          final photo = _photos.removeAt(index);
                          _photos.insert(index + 1, photo);
                        }),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: '사진 삭제',
                  onPressed: () => _remove(index),
                  icon: const Icon(Icons.delete_outline),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Semantics(
                    label: '사진 ${index + 1} 순서 변경',
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
