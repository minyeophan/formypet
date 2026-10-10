import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../core/api_client.dart';
import '../models/activity_record.dart';
import '../models/pet.dart';
import 'photo_preparation.dart';

/// One instance belongs to one open form. Frozen requests are reconciled before
/// later edits, and successful attachment steps are never dispatched again.
enum PhotoSaveStatus {
  ready,
  saving,
  requestUncertain,
  mediaPending,
  savedNeedsRefresh,
  complete,
}

enum PhotoRetryTarget { save, reconcile, upload, refresh, none }

class PhotoSaveDraft {
  String key = const Uuid().v4();
  Map<String, dynamic>? _frozen;
  List<PreparedPhoto>? _photos;
  List<String>? _photoKeys;
  String? savedId;
  bool _textSaved = false;
  Map<String, dynamic>? _pendingUpdate;
  bool _canReplacePendingPhotos = false;

  bool get canReplacePendingPhotos => _canReplacePendingPhotos;

  /// Replace an attachment that was definitively rejected by validation while
  /// retaining the saved record and every attachment that already succeeded.
  void replacePendingPhotos(List<PreparedPhoto> replacements) {
    if (!_canReplacePendingPhotos || _photos == null || _photoKeys == null) {
      throw StateError('No definitively rejected photo can be replaced.');
    }
    final savedPhotos = _photos!.take(_uploaded).toList();
    final savedKeys = _photoKeys!.take(_uploaded).toList();
    _photos = List.unmodifiable([...savedPhotos, ...replacements]);
    _photoKeys = [
      ...savedKeys,
      for (var i = 0; i < replacements.length; i++)
        '$key-photo-${_uploaded + i}-${const Uuid().v4()}',
    ];
    _canReplacePendingPhotos = false;
    lastError = null;
  }

  void skipRemainingPhotos() {
    if (_photos != null) _uploaded = _photos!.length;
    _canReplacePendingPhotos = false;
  }

  bool get hasAttempted => _frozen != null;
  bool get hasPendingSave =>
      status != PhotoSaveStatus.ready && status != PhotoSaveStatus.complete;
  bool get hasConfirmedRecord => savedId != null;
  bool get hasConfirmedPhotos =>
      hasConfirmedRecord &&
      (_photos?.isNotEmpty ?? false) &&
      _uploaded == (_photos?.length ?? 0);
  bool get hasUncertainRequest => status == PhotoSaveStatus.requestUncertain;
  bool get hasUnconfirmedWork => hasPendingSave;
  bool get exitNeedsReconcile =>
      status == PhotoSaveStatus.requestUncertain ||
      status == PhotoSaveStatus.mediaPending ||
      status == PhotoSaveStatus.savedNeedsRefresh;
  int _uploaded = 0;
  Object? lastError;
  PhotoSaveStatus status = PhotoSaveStatus.ready;
  PhotoRetryTarget get retryTarget => switch (status) {
    PhotoSaveStatus.requestUncertain => PhotoRetryTarget.reconcile,
    PhotoSaveStatus.mediaPending => PhotoRetryTarget.upload,
    PhotoSaveStatus.savedNeedsRefresh => PhotoRetryTarget.refresh,
    PhotoSaveStatus.complete => PhotoRetryTarget.none,
    _ => PhotoRetryTarget.save,
  };
  String get message => switch (status) {
    PhotoSaveStatus.mediaPending => mediaUploadErrorMessage(
      lastError ?? StateError('upload pending'),
      fallback: '정보는 저장됐지만 사진 업로드를 완료하지 못했어요. 다시 시도해 주세요.',
    ),
    PhotoSaveStatus.savedNeedsRefresh => '정보와 사진은 저장됐어요. 다시 눌러 저장 결과를 불러와 주세요.',
    PhotoSaveStatus.requestUncertain => '저장 결과를 확인하지 못했어요. 다시 누르면 중복 없이 확인해요.',
    _ => '저장하지 못했어요. 다시 시도해 주세요.',
  };
  String get exitMessage {
    final base = switch (status) {
      PhotoSaveStatus.requestUncertain =>
        '저장 여부를 확인하지 못했어요. 나가더라도 기록이 저장되어 있을 수 있어요.',
      PhotoSaveStatus.mediaPending when hasConfirmedRecord =>
        '기록은 저장됐어요. 아직 업로드하지 못한 사진은 추가되지 않아요.',
      PhotoSaveStatus.savedNeedsRefresh when hasConfirmedPhotos =>
        '기록과 사진은 저장됐어요. 목록에서 다시 확인할 수 있어요.',
      PhotoSaveStatus.savedNeedsRefresh when hasConfirmedRecord =>
        '기록은 저장됐어요. 목록에서 다시 확인할 수 있어요.',
      _ => '저장하지 않은 변경사항은 사라져요.',
    };
    return base;
  }

  void _check(bool Function() current) {
    if (!current()) throw StateError('작성 중인 계정이나 반려동물이 변경됐어요.');
  }

  Future<Map<String, dynamic>> save({
    required String path,
    required Map<String, dynamic> body,
    required List<PreparedPhoto> photos,
    required bool Function() current,
    String? existingId,
    bool refreshFromList = false,
    void Function(Map<String, dynamic>)? validate,
  }) async {
    _check(current);
    _frozen ??= jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
    _photos ??= List.unmodifiable(photos);
    _photoKeys ??= List.generate(
      _photos!.length,
      (index) => '$key-photo-$index',
    );
    savedId ??= existingId;
    try {
      if (savedId == null) {
        status = PhotoSaveStatus.requestUncertain;
        final res = await dio.post(
          path,
          data: _frozen,
          options: Options(
            extra: {'_isRequestCurrent': current},
            headers: {'Idempotency-Key': key},
          ),
        );
        savedId = (unwrap(res) as Map)['id'].toString();
        _textSaved = true;
        _check(current);
      }
      if (_pendingUpdate != null) {
        status = PhotoSaveStatus.requestUncertain;
        _check(current);
        await dio.put(
          '$path/$savedId',
          data: _pendingUpdate,
          options: Options(extra: {'_isRequestCurrent': current}),
        );
        _check(current);
        _frozen = _pendingUpdate;
        _pendingUpdate = null;
        _textSaved = true;
      }
      // A replay above must use the original payload; apply subsequent edits only
      // once the server's committed identity is known.
      if (!_textSaved || jsonEncode(body) != jsonEncode(_frozen)) {
        status = PhotoSaveStatus.requestUncertain;
        _check(current);
        _pendingUpdate = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
        await dio.put(
          '$path/$savedId',
          data: _pendingUpdate,
          options: Options(extra: {'_isRequestCurrent': current}),
        );
        _check(current);
        _frozen = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
        _textSaved = true;
        _pendingUpdate = null;
      }
      status = PhotoSaveStatus.mediaPending;
      for (; _uploaded < _photos!.length; _uploaded++) {
        _check(current);
        final photo = _photos![_uploaded];
        await dio.post(
          '$path/$savedId/media',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              photo.bytes,
              filename: photo.filename,
              contentType: DioMediaType.parse(photo.mimeType),
            ),
          }),
          options: Options(
            extra: {'_isRequestCurrent': current},
            headers: {'Idempotency-Key': _photoKeys![_uploaded]},
          ),
        );
        _check(current);
      }
      status = PhotoSaveStatus.savedNeedsRefresh;
      _check(current);
      final res = await dio.get(
        refreshFromList ? path : '$path/$savedId',
        options: Options(extra: {'_isRequestCurrent': current}),
      );
      _check(current);
      final data = refreshFromList
          ? (unwrap(res) as List).firstWhere(
              (p) => p['id'].toString() == savedId,
            )
          : unwrap(res);
      final parsed = Map<String, dynamic>.from(data as Map);
      validate?.call(parsed);
      status = PhotoSaveStatus.complete;
      return parsed;
    } catch (error) {
      lastError = error;
      final code = error is DioException
          ? error.response?.statusCode
          : error is ApiException
          ? error.statusCode
          : null;
      // Validation is a definitive rejection. A corrected request is a new
      // intent; ambiguous transport failures must keep the frozen request.
      if ({400, 422}.contains(code) &&
          status == PhotoSaveStatus.requestUncertain) {
        _pendingUpdate = null;
        if (savedId == null) {
          _frozen = null;
          _photos = null;
          key = const Uuid().v4();
        }
        status = PhotoSaveStatus.ready;
      }
      if (status == PhotoSaveStatus.mediaPending &&
          _isReplaceablePhotoRejection(error)) {
        _canReplacePendingPhotos = true;
      }
      rethrow;
    }
  }

  bool _isReplaceablePhotoRejection(Object error) {
    final api = error is ApiException
        ? error
        : error is DioException
        ? parseApiError(error)
        : null;
    return {400, 413, 422}.contains(api?.statusCode) ||
        {
          'MEDIA_TOO_LARGE',
          'UPLOAD_TOO_LARGE',
          'MEDIA_UNSUPPORTED_FORMAT',
          'MEDIA_INVALID_FILE',
        }.contains(api?.errorCode);
  }
}

class RecordPhotoDraft extends PhotoSaveDraft {
  Future<ActivityRecord> saveRecord({
    required String petId,
    required Map<String, dynamic> body,
    required List<PreparedPhoto> photos,
    required bool Function() current,
  }) async => ActivityRecord.fromJson(
    await save(
      path: '/api/v1/pets/$petId/records',
      body: body,
      photos: photos,
      current: current,
      validate: ActivityRecord.fromJson,
    ),
  );
}

class PetPhotoDraft extends PhotoSaveDraft {
  Future<Pet> savePet({
    String? petId,
    required Map<String, dynamic> body,
    required List<PreparedPhoto> photos,
    required bool Function() current,
  }) async => Pet.fromJson(
    await save(
      path: '/api/v1/pets',
      existingId: petId,
      body: body,
      photos: photos,
      current: current,
      refreshFromList: true,
      validate: Pet.fromJson,
    ),
  );
}
