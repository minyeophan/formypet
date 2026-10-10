import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/pet_log.dart';

class PetLogService {
  static final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);
  static void notifyChanged() => dataRevision.value++;

  Future<bool> exampleDismissed(String petId) async {
    final r = await dio.get('/api/v1/pets/$petId/pet-logs/preferences');
    return (r.data as Map)['data'] as bool;
  }

  Future<void> dismissExample(String petId) async {
    await dio.put(
      '/api/v1/pets/$petId/pet-logs/preferences',
      data: {'exampleDismissed': true},
    );
  }

  Future<PetLogPage> list(
    String petId, {
    int? year,
    int? month,
    String? cursor,
  }) async {
    final r = await dio.get(
      '/api/v1/pets/$petId/pet-logs',
      queryParameters: {
        ...?(year == null ? null : {'year': year}),
        ...?(month == null ? null : {'month': month}),
        'limit': 20,
        ...?(cursor == null ? null : {'cursor': cursor}),
      },
    );
    return PetLogPage.fromJson((r.data as Map)['data'] as Map<String, dynamic>);
  }

  Future<PetLog> get(String petId, String id) async {
    final r = await dio.get('/api/v1/pets/$petId/pet-logs/$id');
    return PetLog.fromJson((r.data as Map)['data'] as Map<String, dynamic>);
  }

  Future<int> upload(
    String petId,
    Uint8List bytes,
    String filename,
    String key,
  ) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final r = await dio.post(
      '/api/v1/pets/$petId/pet-logs/media',
      data: form,
      options: Options(headers: {'Idempotency-Key': key}),
    );
    return ((r.data as Map)['data'] as Map)['id'] as int;
  }

  Future<PetLog> create(
    String petId,
    DateTime at,
    String? note,
    List<int> ids,
    String key,
  ) async {
    final r = await dio.post(
      '/api/v1/pets/$petId/pet-logs',
      data: {
        'date':
            '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}',
        'time':
            '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:00',
        'note': note,
        'mediaIds': ids,
      },
      options: Options(headers: {'Idempotency-Key': key}),
    );
    return PetLog.fromJson((r.data as Map)['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String petId, String id, int version, String key) async =>
      dio.delete(
        '/api/v1/pets/$petId/pet-logs/$id',
        queryParameters: {'version': version},
        options: Options(headers: {'Idempotency-Key': key}),
      );

  Future<PetLog> update(
    String petId,
    String id,
    DateTime at,
    String? note,
    List<int> ids,
    int version,
    String key,
  ) async {
    final r = await dio.put(
      '/api/v1/pets/$petId/pet-logs/$id',
      data: {
        'date':
            '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}',
        'time':
            '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:00',
        'note': note,
        'mediaIds': ids,
        'version': version,
      },
      options: Options(headers: {'Idempotency-Key': key}),
    );
    return PetLog.fromJson((r.data as Map)['data'] as Map<String, dynamic>);
  }
}
