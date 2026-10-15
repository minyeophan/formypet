import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../services/pet_log_export_source.dart';
import '../../services/pet_log_book_image_composer.dart';
import '../../services/pet_log_photo_gallery_saver.dart';
import '../../services/pet_log_video_exporter.dart';
import '../../services/pet_log_video_gallery_saver.dart';
import '../../services/pet_log_video_preview.dart';
import '../../services/pet_log_temp_files.dart';
import '../../services/pet_log_temp_file_registry.dart';
import '../../services/pet_log_service.dart';
import '../../models/pet_log.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pet_log_export_sheet.dart';
import '../../widgets/app_success_toast.dart';
import '../../widgets/authenticated_network_image.dart';

enum PetLogExportKind { image, video }

class PetLogExportScreen extends StatefulWidget {
  const PetLogExportScreen({
    super.key,
    required this.petId,
    required this.year,
    required this.month,
    required this.all,
    required this.kind,
  });
  final String petId;
  final int year;
  final int? month;
  final bool all;
  final PetLogExportKind kind;
  @override
  State<PetLogExportScreen> createState() => _PetLogExportScreenState();
}

class _PetLogExportScreenState extends State<PetLogExportScreen> {
  final _service = PetLogService();
  CancelToken? _loadCancelToken;
  final _gridController = ScrollController();
  final _selection = PetLogExportSelection(limit: PetLogExportPhotoLimit.free);
  final _pageAccumulator = PetLogExportPageAccumulator();
  List<PetLogExportPhoto> get _photos => _pageAccumulator.photos;
  String? get _nextCursor => _pageAccumulator.nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  int _automaticPageLoads = 0;
  String? _error;
  String? _pageError;
  bool _limitVisible = false;
  String get _period => widget.all
      ? '전체 기간'
      : widget.month == null
      ? '${widget.year}년'
      : '${widget.year}년 ${widget.month}월';

  @override
  void initState() {
    super.initState();
    _gridController.addListener(_maybeLoadNextPage);
    _load();
  }

  @override
  void didUpdateWidget(covariant PetLogExportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId ||
        oldWidget.year != widget.year ||
        oldWidget.month != widget.month ||
        oldWidget.all != widget.all ||
        oldWidget.kind != widget.kind) {
      _load();
    }
  }

  Future<void> _load() async {
    _loadCancelToken?.cancel('A newer page load started.');
    final token = _loadCancelToken = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
      _pageError = null;
      _loadingMore = false;
      _automaticPageLoads = 0;
      _pageAccumulator.reset();
      _selection.clear();
    });
    try {
      final page = await _service.list(
        widget.petId,
        year: widget.all ? null : widget.year,
        month: widget.month,
        cancelToken: token,
      );
      if (!mounted || token != _loadCancelToken) return;
      setState(() {
        _appendPage(page);
        _loading = false;
      });
      _scheduleNextPageIfNeeded();
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '사진을 불러오지 못했어요.';
        });
      }
    }
  }

  Future<void> _loadNextPage({bool automatic = false}) async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _loading) return;
    if (automatic && _automaticPageLoads >= 3) return;
    if (automatic) {
      _automaticPageLoads++;
    } else {
      _automaticPageLoads = 0;
    }
    _loadCancelToken?.cancel('A newer page load started.');
    final token = _loadCancelToken = CancelToken();
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final page = await _service.list(
        widget.petId,
        year: widget.all ? null : widget.year,
        month: widget.month,
        cursor: cursor,
        cancelToken: token,
      );
      if (!mounted || token != _loadCancelToken) return;
      setState(() {
        _appendPage(page);
        _loadingMore = false;
      });
      _scheduleNextPageIfNeeded();
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _pageError = '사진을 더 불러오지 못했어요.';
        });
      }
    }
  }

  void _appendPage(PetLogPage page) {
    _pageAccumulator.append(page);
  }

  void _maybeLoadNextPage() {
    if (!_gridController.hasClients || _loadingMore || _nextCursor == null) {
      return;
    }
    if (_gridController.position.extentAfter < 500) {
      _loadNextPage(automatic: true);
    }
  }

  void _scheduleNextPageIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadNextPage();
    });
  }

  @override
  void dispose() {
    _loadCancelToken?.cancel('Export selection screen closed.');
    _gridController
      ..removeListener(_maybeLoadNextPage)
      ..dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final ordered = _selection.ids
        .map((id) => _photos.firstWhere((p) => p.photo.id == id))
        .toList();
    if (ordered.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PetLogExportResultScreen(
          kind: widget.kind,
          photos: ordered,
          period: _period,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppHeader(
      titleSize: 21,
      leadingWidth: 55,
      title: widget.kind == PetLogExportKind.image ? '이미지 만들기' : '영상 만들기',
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('다시 시도')),
              ],
            ),
          )
        : _photos.isEmpty &&
              (_loadingMore || _nextCursor != null || _pageError != null)
        ? Center(
            child: _loadingMore
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pageError == null
                            ? '사진을 더 불러올 수 있어요.'
                            : '사진 목록을 불러오지 못했어요.',
                      ),
                      TextButton(
                        onPressed: _nextCursor == null ? _load : _loadNextPage,
                        child: Text(_pageError == null ? '더 불러오기' : '다시 시도'),
                      ),
                    ],
                  ),
          )
        : _photos.isEmpty
        ? const Center(child: Text('이 기간에는 사진이 없어요.'))
        : _selectionViewport(
            (compact) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _period,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '선택 사진 순서 변경',
                            onPressed: _selection.ids.length < 2
                                ? null
                                : _reorder,
                            icon: const Icon(Icons.swap_horiz),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              if (_selection.ids.isNotEmpty) {
                                _selection.clear();
                              } else {
                                for (final item in _photos.take(
                                  _selection.limit,
                                )) {
                                  _selection.add(item.photo.id);
                                }
                              }
                            }),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: Text(
                              _selection.ids.isEmpty ? '전체 선택' : '전체 해제',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.kind == PetLogExportKind.video
                            ? '영상에 담을 순간을 골라주세요'
                            : '이미지에 담을 순간을 골라주세요',
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.5,
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _photoGridViewport(
                  compact,
                  GridView.builder(
                    shrinkWrap: compact,
                    physics: compact
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    controller: compact ? null : _gridController,
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 0,
                      mainAxisExtent: _photoRowExtent(context),
                    ),
                    itemCount:
                        _photos.length +
                        (_nextCursor == null && _pageError == null ? 0 : 1),
                    itemBuilder: (context, index) {
                      if (index == _photos.length) {
                        return Center(
                          child: _pageError == null
                              ? TextButton(
                                  onPressed: _loadingMore
                                      ? null
                                      : _loadNextPage,
                                  child: const Text('더 불러오기'),
                                )
                              : _nextCursor == null
                              ? TextButton(
                                  onPressed: _load,
                                  child: const Text('목록 다시 불러오기'),
                                )
                              : TextButton(
                                  onPressed: _loadNextPage,
                                  child: const Text('다시 시도'),
                                ),
                        );
                      }
                      final item = _photos[index];
                      final selected = _selection.contains(item.photo.id);
                      final n = _selection.ids.indexOf(item.photo.id) + 1;
                      return DragTarget<String>(
                        onWillAcceptWithDetails: (details) =>
                            selected && details.data != item.photo.id,
                        onAcceptWithDetails: (details) {
                          final from = _selection.ids.indexOf(details.data);
                          final to = _selection.ids.indexOf(item.photo.id);
                          if (from >= 0 && to >= 0) {
                            setState(() => _selection.reorder(from, to));
                          }
                        },
                        builder: (context, candidate, rejected) =>
                            LongPressDraggable<String>(
                              data: item.photo.id,
                              maxSimultaneousDrags: selected ? 1 : 0,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: 106,
                                  height: 106,
                                  child: _photo(item),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: .35,
                                child: _photoTile(item, n, selected),
                              ),
                              child: _photoTile(item, n, selected),
                            ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.kind == PetLogExportKind.video
                            ? '사진 ${_selection.ids.length}장   ${_selection.ids.isEmpty ? '사진을 선택해주세요' : '영상 길이 약 ${_selection.ids.length * 3}초'}'
                            : '${_selection.ids.length}장 선택',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 23 / 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      if (widget.kind == PetLogExportKind.video) ...[
                        const SizedBox(height: 11),
                        const Text(
                          '사진이 많을수록 영상 제작에 시간이 걸릴 수 있어요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: petLogExportMuted,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          '사진 한 장당 3초  기록 글은 영상에 포함되지 않아요.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 17 / 11,
                            color: petLogExportMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 34),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: petLogExportButtonStyle(),
                        onPressed: _selection.ids.isEmpty ? null : _create,
                        child: Text(
                          widget.kind == PetLogExportKind.image
                              ? '이미지 미리보기'
                              : _selection.ids.isEmpty
                              ? '사진을 선택해주세요'
                              : '영상 만들기',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );

  Widget _photoGridViewport(bool compact, Widget grid) =>
      compact ? grid : Expanded(child: grid);

  Widget _selectionViewport(Widget Function(bool) builder) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final compact =
          constraints.maxHeight <
          350 + 650 * (scale - 1).clamp(0, double.infinity);
      if (!compact) return builder(false);
      return SingleChildScrollView(child: builder(true));
    },
  );

  double _photoRowExtent(BuildContext context) {
    final text = TextPainter(
      text: TextSpan(
        text: '12월 31일',
        style: TextStyle(
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          fontSize: 11,
          height: 17 / 11,
        ),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 106);
    final height = (115 + text.height).clamp(132.0, double.infinity);
    text.dispose();
    return height;
  }

  Future<void> _showLimit() async {
    if (_limitVisible) return;
    _limitVisible = true;
    try {
      await showPetLogExportSheet(
        context,
        title: '기본 플랜은 사진을 최대 5장까지\n선택할 수 있어요.',
        description: '선택한 사진을 해제하면 다른 사진을 고를 수 있어요.',
      );
    } finally {
      _limitVisible = false;
    }
  }

  Future<void> _reorder() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, updateSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('사진 순서 변경'),
              ),
              Flexible(
                child: ReorderableListView(
                  shrinkWrap: true,
                  onReorderItem: (from, to) {
                    setState(() => _selection.reorder(from, to));
                    updateSheet(() {});
                  },
                  children: [
                    for (final id in _selection.ids)
                      ListTile(
                        key: ValueKey('order-$id'),
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: _photo(
                            _photos.firstWhere((p) => p.photo.id == id),
                          ),
                        ),
                        title: Text('${_selection.ids.indexOf(id) + 1}번째 사진'),
                        trailing: const Icon(Icons.drag_handle),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(PetLogExportPhoto item) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: AuthenticatedNetworkImage(
      url: item.photo.url,
      fit: BoxFit.contain,
      fallback: const ColoredBox(color: AppColors.surfaceSoft),
    ),
  );

  Widget _photoTile(PetLogExportPhoto item, int number, bool selected) =>
      GestureDetector(
        key: ValueKey(item.photo.id),
        onTap: () {
          if (selected) {
            setState(() => _selection.remove(item.photo.id));
          } else if (_selection.ids.length >= _selection.limit) {
            _showLimit();
          } else {
            setState(() => _selection.add(item.photo.id));
          }
        },
        child: Column(
          children: [
            SizedBox(
              width: 106,
              height: 106,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _photo(item),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.primary : Colors.white,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : petLogExportMuted,
                        ),
                      ),
                      child: selected
                          ? Text(
                              '$number',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 106,
              child: Text(
                _photoDate(item.logDate),
                style: const TextStyle(
                  fontSize: 11,
                  height: 17 / 11,
                  color: petLogExportMuted,
                ),
              ),
            ),
          ],
        ),
      );

  String _photoDate(String date) {
    final parsed = DateTime.tryParse(date);
    return parsed == null ? date : '${parsed.month}월 ${parsed.day}일';
  }
}

class PetLogExportResultScreen extends StatefulWidget {
  const PetLogExportResultScreen({
    super.key,
    required this.kind,
    required this.photos,
    this.period = '전체 기간',
  });
  final PetLogExportKind kind;
  final List<PetLogExportPhoto> photos;
  final String period;
  @override
  State<PetLogExportResultScreen> createState() =>
      _PetLogExportResultScreenState();
}

class _PetLogExportResultScreenState extends State<PetLogExportResultScreen> {
  Uint8List? _image;
  String? _video;
  VideoPlayerController? _player;
  String? _error;
  bool _busy = true;
  bool _disposed = false;
  bool _sharing = false;
  bool _saving = false;
  bool _encoding = false;
  double? _progress;
  CancelToken? _cancelToken;
  Future<void>? _playerDisposal;
  final _temporaryFiles = PetLogTempFileRegistry();
  final _shareButtonKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    _cancelToken = CancelToken();
    var succeeded = false;
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
        _progress = null;
        _encoding = false;
      });
    }
    try {
      final bytes = <Uint8List>[];
      for (final photo in widget.photos) {
        if (_disposed) return;
        final response = await dio.get<List<int>>(
          photo.photo.url,
          options: Options(responseType: ResponseType.bytes),
          cancelToken: _cancelToken,
        );
        if (response.data == null || response.data!.isEmpty) {
          throw StateError('Selected photo could not be downloaded.');
        }
        bytes.add(Uint8List.fromList(response.data!));
      }
      if (widget.kind == PetLogExportKind.image) {
        _image = await PetLogBookImageComposer.compose(bytes);
      } else {
        if (!PetLogVideoExporter.isSupported) {
          throw UnsupportedError(
            'Video export is available on Android and iOS.',
          );
        }
        final paths = <String>[];
        for (var i = 0; i < bytes.length; i++) {
          final normalized = await PetLogBookImageComposer.normalizePhoto(
            bytes[i],
          );
          final path = await writePetLogTempFile(normalized, 'jpg', i);
          _temporaryFiles.register(path);
          paths.add(path);
        }
        final output = await writePetLogTempFile(
          const <int>[],
          'mp4',
          bytes.length,
        );
        _temporaryFiles.register(output);
        if (_disposed) return;
        setState(() => _encoding = true);
        _video = await PetLogVideoExporter.create(
          paths,
          output,
          cancelToken: _cancelToken,
          onProgress: (value) {
            if (mounted && !_disposed) setState(() => _progress = value);
          },
        );
        if (_disposed) return;
        final player = await createPetLogVideoPreview(_video!);
        try {
          await player.initialize();
          await player.setLooping(false);
        } catch (_) {
          await player.dispose();
          rethrow;
        }
        if (_disposed) {
          await player.dispose();
          return;
        }
        await _player?.dispose();
        _player = player;
      }
      succeeded = true;
    } catch (error) {
      if (error is! DioException || error.type != DioExceptionType.cancel) {
        _error = '결과물을 만들지 못했어요. 연결 상태를 확인하고 다시 시도해주세요.';
      }
    } finally {
      if (!succeeded) {
        await _temporaryFiles.cleanup(deletePetLogTempFile);
        _video = null;
      } else if (_video != null) {
        await _temporaryFiles.cleanupExcept({_video!}, deletePetLogTempFile);
      }
      if (_disposed) await _cleanupTemporaryFiles();
    }
    // The route pops on the next frame; a cancelled job has no preview to render.
    if (_cancelToken?.isCancelled == true || _allowPop) return;
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    if (_saving || _sharing || _busy) return;
    setState(() => _saving = true);
    try {
      if (_image != null) {
        await savePetLogPhotoToGallery(_image!, 'pet-log.jpg');
      } else if (_video != null) {
        await savePetLogVideoToGallery(_video!);
      }
      if (mounted) {
        final shareBox = _shareButtonKey.currentContext?.findRenderObject();
        showAppSuccessToast(
          context,
          '저장 완료',
          bottomOffset:
              widget.kind == PetLogExportKind.video && shareBox is RenderBox
              ? MediaQuery.sizeOf(context).height -
                    shareBox.localToGlobal(Offset.zero).dy +
                    14
              : null,
        );
      }
    } catch (error) {
      if (mounted) {
        final denied =
            error is GalException &&
            error.type == GalExceptionType.accessDenied;
        final retry = await showPetLogExportSheet(
          context,
          title: denied
              ? '사진 저장 권한이 필요해요'
              : widget.kind == PetLogExportKind.video
              ? '영상을 저장하지 못했어요'
              : '결과물을 저장하지 못했어요',
          description: denied
              ? '${widget.kind == PetLogExportKind.video ? '완성된 영상을' : '완성된 이미지를'} 사진첩에 저장하려면\n설정에서 사진 추가 권한을 허용해주세요.'
              : '휴대폰 저장 공간을 확인하고 다시 시도해주세요.\n미리보기로 돌아가 공유할 수도 있어요.',
          confirm: denied
              ? (defaultTargetPlatform == TargetPlatform.android
                    ? '설정 열기'
                    : '확인')
              : '저장 다시 시도',
          secondary: denied ? '나중에' : '미리보기로 돌아가기',
        );
        if (retry == true && mounted) {
          if (denied) {
            if (defaultTargetPlatform != TargetPlatform.android) return;
            try {
              await const MethodChannel(
                'com.formypet/pet_log_video_export',
              ).invokeMethod<void>('openAppSettings');
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('기기 설정에서 앱 권한을 확인해주세요.')),
                );
              }
            }
          } else {
            _saving = false;
            await _save();
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      } else {
        _saving = false;
      }
      if (_disposed) await _cleanupAfterPlayerDisposal();
    }
  }

  Future<void> _share() async {
    if (_saving || _sharing || _busy) return;
    setState(() => _sharing = true);
    try {
      final path = _video;
      final bytes = _image;
      final file = path != null
          ? XFile(path)
          : XFile.fromData(bytes!, mimeType: 'image/jpeg', name: 'pet-log.jpg');
      await SharePlus.instance.share(
        ShareParams(files: [file], sharePositionOrigin: _shareOrigin()),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유를 시작하지 못했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      } else {
        _sharing = false;
      }
      if (_disposed) {
        await _cleanupAfterPlayerDisposal();
      }
    }
  }

  Rect _shareOrigin() {
    final renderObject = _shareButtonKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (rect.width > 0 && rect.height > 0) return rect;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  Future<void> _cleanupTemporaryFiles() async {
    if (_sharing || _saving) return;
    await _temporaryFiles.cleanup(deletePetLogTempFile);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel('Export screen closed.');
    final player = _player;
    if (player != null) _playerDisposal = player.dispose();
    if (!_sharing && !_saving) _cleanupAfterPlayerDisposal();
    super.dispose();
  }

  Future<void> _cleanupAfterPlayerDisposal() async {
    try {
      await _playerDisposal;
    } catch (_) {
      // Continue file cleanup even if the preview player fails to release.
    }
    await _cleanupTemporaryFiles();
  }

  bool _confirmingCancel = false;
  bool _allowPop = false;

  Future<void> _leave() async {
    if (_confirmingCancel) return;
    if (!_busy) {
      Navigator.of(context).pop();
      return;
    }
    _confirmingCancel = true;
    final keepGoing = await showPetLogExportSheet(
      context,
      title: '영상 제작을 취소할까요?',
      description: '만들던 영상은 중단되지만,\n선택한 사진과 원본 기록은 그대로 남아요.',
      confirm: '계속 만들기',
      secondary: '제작 취소',
    );
    _confirmingCancel = false;
    if (!mounted || keepGoing != false) return;
    setState(() => _allowPop = true);
    _cancelToken?.cancel('User cancelled export.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _time(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _generation() => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 85),
              SizedBox(
                width: 148,
                height: 148,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AuthenticatedNetworkImage(
                    url: widget.photos.first.photo.url,
                    fit: BoxFit.contain,
                    fallback: const ColoredBox(color: AppColors.surfaceSoft),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '우리 아이의 순간을\n하나의 영상으로 모으고 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 27),
              Text(
                !_encoding
                    ? '사진을 준비하고 있어요'
                    : _progress == null
                    ? '영상을 만드는 중'
                    : '영상을 만드는 중 ${(_progress! * 100).floor()}%',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 17),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LinearProgressIndicator(
                  value: _encoding ? _progress : null,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: const Color(0xFFEAF7F0),
                  color: AppColors.primary,
                  stopIndicatorRadius: 0,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '사진 ${widget.photos.length}장  완성 영상 약 ${widget.photos.length * 3}초',
                style: const TextStyle(
                  fontSize: 13,
                  height: 20 / 13,
                  color: petLogExportMuted,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '제작이 끝날 때까지 이 화면을 유지해주세요.\n사진 수와 휴대폰 성능에 따라 시간이 달라져요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: petLogExportMuted,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: FilledButton(
          style: petLogExportButtonStyle(secondary: true),
          onPressed: _leave,
          child: const Text('제작 취소'),
        ),
      ),
    ],
  );

  Widget _videoPreview() => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: _player!,
    builder: (context, value, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.period}의 순간들',
          style: const TextStyle(
            fontSize: 18,
            height: 1.5,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '사진 ${widget.photos.length}장  ${_time(value.duration)}',
          style: const TextStyle(
            fontSize: 13,
            height: 20 / 13,
            color: petLogExportMuted,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 27),
            child: Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: VideoPlayer(_player!),
                    ),
                    IconButton.filled(
                      tooltip: value.isPlaying ? '일시정지' : '재생',
                      iconSize: 26,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        fixedSize: const Size(52, 52),
                      ),
                      onPressed: () async {
                        if (value.isPlaying) {
                          await _player!.pause();
                        } else {
                          if (value.position >= value.duration) {
                            await _player!.seekTo(Duration.zero);
                          }
                          await _player!.play();
                        }
                      },
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.border,
            thumbColor: AppColors.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            padding: EdgeInsets.zero,
            value: value.position.inMilliseconds.toDouble().clamp(
              0,
              value.duration.inMilliseconds.toDouble(),
            ),
            max: value.duration.inMilliseconds.toDouble().clamp(
              1,
              double.infinity,
            ),
            onChanged: (position) =>
                _player!.seekTo(Duration(milliseconds: position.round())),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _time(value.position),
              style: const TextStyle(
                fontSize: 11,
                height: 17 / 11,
                color: petLogExportMuted,
              ),
            ),
            Text(
              _time(value.duration),
              style: const TextStyle(
                fontSize: 11,
                height: 17 / 11,
                color: petLogExportMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 43),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: _shareButtonKey,
            style: petLogExportButtonStyle(),
            onPressed: _saving || _sharing ? null : _share,
            child: const Text('공유하기'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            style: petLogExportButtonStyle(secondary: true),
            onPressed: _saving || _sharing ? null : _save,
            child: Text(_saving ? '저장 중' : '내 기기에 저장'),
          ),
        ),
      ],
    ),
  );

  Widget _videoFailure() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    child: Column(
      children: [
        const Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '영상을 만들지 못했어요',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '선택한 사진은 그대로예요.\n잠시 후 다시 시도해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: petLogExportMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        FilledButton(
          style: petLogExportButtonStyle(),
          onPressed: _generate,
          child: const Text('다시 만들기'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: petLogExportButtonStyle(secondary: true),
          onPressed: _leave,
          child: const Text('사진 다시 고르기'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy || _allowPop || widget.kind == PetLogExportKind.image,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppHeader(
        titleSize: 21,
        leadingWidth: 55,
        title: widget.kind == PetLogExportKind.image
            ? '이미지 미리보기'
            : _busy || _error != null
            ? '영상 만들기'
            : '영상 미리보기',
        showBackButton: true,
        onBack: widget.kind == PetLogExportKind.video
            ? _leave
            : () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        top: false,
        minimum: widget.kind == PetLogExportKind.video
            ? const EdgeInsets.only(bottom: 34)
            : EdgeInsets.zero,
        child: _busy
            ? widget.kind == PetLogExportKind.video
                  ? _generation()
                  : const Center(child: CircularProgressIndicator())
            : _error != null
            ? widget.kind == PetLogExportKind.video
                  ? _videoFailure()
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _generate,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    )
            : Padding(
                padding: _player != null
                    ? const EdgeInsets.fromLTRB(20, 20, 20, 12)
                    : const EdgeInsets.all(20),
                child: _player != null
                    ? LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              child: SizedBox(
                                height: constraints.maxHeight.clamp(
                                  480 *
                                      MediaQuery.textScalerOf(context).scale(1),
                                  double.infinity,
                                ),
                                child: _videoPreview(),
                              ),
                            ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: InteractiveViewer(
                              child: Image.memory(_image!, fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saving || _sharing ? null : _save,
                                  icon: const Icon(Icons.download),
                                  label: const Text('저장'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  key: _shareButtonKey,
                                  onPressed: _saving || _sharing
                                      ? null
                                      : _share,
                                  icon: const Icon(Icons.ios_share),
                                  label: const Text('공유'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
      ),
    ),
  );
}
