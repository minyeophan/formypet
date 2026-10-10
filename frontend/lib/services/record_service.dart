import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/activity_record.dart';

class RecordMediaUpload {
  final Uint8List bytes;
  final String filename;

  const RecordMediaUpload({required this.bytes, required this.filename});
}

enum RecordSaveStage { mediaPending, savedNeedsRefresh }

/// A committed record must never be recreated or deleted to recover a read.
class RecordSaveException implements Exception {
  final ActivityRecord record;
  final RecordSaveStage stage;
  final Object cause;
  const RecordSaveException(this.record, this.stage, this.cause);

  @override
  String toString() => stage == RecordSaveStage.savedNeedsRefresh
      ? '기록과 사진은 저장됐어요. 다시 저장하지 말고 목록을 다시 불러와 주세요.'
      : '기록은 저장됐지만 사진 업로드를 완료하지 못했어요. 사진 업로드를 다시 시도해 주세요.';
}

class RecordService {
  Future<List<ActivityRecord>> getRecords(
    String petId, {
    String? date,
    String? typeId,
    int? limit,
  }) async {
    final params = <String, dynamic>{};
    if (date != null) params['date'] = date;
    if (typeId != null) params['typeId'] = typeId;
    if (limit != null) params['limit'] = limit;

    final res = await dio.get(
      '/api/v1/pets/$petId/records',
      queryParameters: params.isNotEmpty ? params : null,
    );
    final list = unwrap(res) as List<dynamic>;
    return list
        .map((e) => ActivityRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActivityRecord> createRecord(
    String petId,
    Map<String, dynamic> body,
  ) async {
    final res = await dio.post('/api/v1/pets/$petId/records', data: body);
    return ActivityRecord.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<ActivityRecord> updateRecord(
    String petId,
    String recordId,
    Map<String, dynamic> body,
  ) async {
    final res = await dio.put(
      '/api/v1/pets/$petId/records/$recordId',
      data: body,
    );
    return ActivityRecord.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<ActivityRecord> getRecord(String petId, String recordId) async {
    final res = await dio.get('/api/v1/pets/$petId/records/$recordId');
    return ActivityRecord.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteRecord(String petId, String recordId) async {
    await dio.delete('/api/v1/pets/$petId/records/$recordId');
  }

  // Creation, attachment and read-back have separate recovery semantics.
  Future<ActivityRecord> createRecordWithMedia({
    required String petId,
    required Map<String, dynamic> body,
    required List<File> files,
  }) async {
    final record = await createRecord(petId, body);
    if (files.isEmpty) return record;

    try {
      await _uploadMedia(petId, record.id, files);
    } catch (e) {
      throw RecordSaveException(record, RecordSaveStage.mediaPending, e);
    }
    return _readSavedRecord(petId, record);
  }

  Future<ActivityRecord> createRecordWithMediaBytes({
    required String petId,
    required Map<String, dynamic> body,
    required List<RecordMediaUpload> files,
  }) async {
    final record = await createRecord(petId, body);
    if (files.isEmpty) return record;

    try {
      await _uploadMediaBytes(petId, record.id, files);
    } catch (e) {
      throw RecordSaveException(record, RecordSaveStage.mediaPending, e);
    }
    return _readSavedRecord(petId, record);
  }

  Future<ActivityRecord> _readSavedRecord(String petId, ActivityRecord record) async {
    try {
      return await getRecord(petId, record.id);
    } catch (e) {
      throw RecordSaveException(record, RecordSaveStage.savedNeedsRefresh, e);
    }
  }

  Future<void> _uploadMedia(
    String petId,
    String recordId,
    List<File> files,
  ) async {
    for (final file in files) {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
      });
      await dio.post(
        '/api/v1/pets/$petId/records/$recordId/media',
        data: formData,
      );
    }
  }

  Future<void> _uploadMediaBytes(
    String petId,
    String recordId,
    List<RecordMediaUpload> files,
  ) async {
    for (final file in files) {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes, filename: file.filename),
      });
      await dio.post(
        '/api/v1/pets/$petId/records/$recordId/media',
        data: formData,
      );
    }
  }
}
