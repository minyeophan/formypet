import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _gridController.addListener(_maybeLoadNextPage);
    _load();
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
      if (!mounted) return;
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
      if (!mounted) return;
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
        builder: (_) =>
            PetLogExportResultScreen(kind: widget.kind, photos: ordered),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppHeader(
      title: widget.kind == PetLogExportKind.image ? '이미지 만들기' : '영상 만들기',
      showBackButton: true,
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
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '사진을 최대 5장 선택해 순서를 정해주세요. (${_selection.ids.length}/5)',
                ),
              ),
              if (_selection.ids.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    onReorderItem: (a, b) =>
                        setState(() => _selection.reorder(a, b)),
                    children: [
                      for (final id in _selection.ids) _selectedTile(id),
                    ],
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  controller: _gridController,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount:
                      _photos.length +
                      (_nextCursor == null && _pageError == null ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (index == _photos.length) {
                      return Center(
                        child: _pageError == null
                            ? TextButton(
                                onPressed: _loadingMore ? null : _loadNextPage,
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
                    return GestureDetector(
                      key: ValueKey(item.photo.id),
                      onTap: () => setState(() {
                        if (selected) {
                          _selection.remove(item.photo.id);
                        } else if (!_selection.add(item.photo.id)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('사진은 최대 5장까지 선택할 수 있어요.'),
                            ),
                          );
                        }
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AuthenticatedNetworkImage(
                            url: item.photo.url,
                            fit: BoxFit.cover,
                            fallback: const ColoredBox(
                              color: AppColors.surfaceSoft,
                            ),
                          ),
                          if (selected) Container(color: Colors.black38),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: CircleAvatar(
                              radius: 13,
                              backgroundColor: selected
                                  ? AppColors.primary
                                  : Colors.black45,
                              child: Text(
                                selected ? '$n' : '+',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selection.ids.isEmpty ? null : _create,
                      child: Text(
                        widget.kind == PetLogExportKind.image
                            ? '이미지 미리보기'
                            : '영상 만들기',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );

  Widget _selectedTile(String id) {
    final item = _photos.firstWhere((p) => p.photo.id == id);
    return Container(
      key: ValueKey('selected-$id'),
      width: 82,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AuthenticatedNetworkImage(
            url: item.photo.url,
            fit: BoxFit.cover,
            fallback: const ColoredBox(color: AppColors.surfaceSoft),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => setState(() => _selection.remove(id)),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class PetLogExportResultScreen extends StatefulWidget {
  const PetLogExportResultScreen({
    super.key,
    required this.kind,
    required this.photos,
  });
  final PetLogExportKind kind;
  final List<PetLogExportPhoto> photos;
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
        _video = await PetLogVideoExporter.create(
          paths,
          output,
          cancelToken: _cancelToken,
        );
        if (_disposed) return;
        final player = await createPetLogVideoPreview(_video!);
        try {
          await player.initialize();
          await player.setLooping(true);
          await player.play();
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
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    try {
      if (_image != null) {
        await savePetLogPhotoToGallery(_image!, 'pet-log.jpg');
      } else if (_video != null) {
        await savePetLogVideoToGallery(_video!);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기기에 저장했어요.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장하지 못했어요. 권한과 저장 공간을 확인해주세요.')),
        );
      }
    }
  }

  Future<void> _share() async {
    _sharing = true;
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
      _sharing = false;
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
    await _temporaryFiles.cleanup(deletePetLogTempFile);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel('Export screen closed.');
    final player = _player;
    if (player != null) _playerDisposal = player.dispose();
    if (!_sharing) _cleanupAfterPlayerDisposal();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppHeader(
      title: widget.kind == PetLogExportKind.image ? '이미지 미리보기' : '영상 미리보기',
      showBackButton: true,
    ),
    body: Center(
      child: _busy
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('결과물을 만들고 있어요.'),
              ],
            )
          : _error != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _generate, child: const Text('다시 시도')),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _image != null
                        ? InteractiveViewer(
                            child: Image.memory(_image!, fit: BoxFit.contain),
                          )
                        : _player == null
                        ? const SizedBox.shrink()
                        : AspectRatio(
                            aspectRatio: _player!.value.aspectRatio,
                            child: VideoPlayer(_player!),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.download),
                          label: const Text('저장'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: _shareButtonKey,
                          onPressed: _share,
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
  );
}
