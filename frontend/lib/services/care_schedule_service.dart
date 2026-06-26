import '../core/api_client.dart';
import '../models/care_schedule.dart';

class CareScheduleService {
  Future<List<CareSchedule>> getSchedules(String petId) async {
    final res = await dio.get('/api/v1/pets/$petId/care-schedules');
    final list = unwrap(res) as List<dynamic>;
    return list
        .map((item) => CareSchedule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CareSchedule> createSchedule(
    String petId,
    CareSchedule schedule,
  ) async {
    final res = await dio.post(
      '/api/v1/pets/$petId/care-schedules',
      data: schedule.toRequestJson(),
    );
    return CareSchedule.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<CareSchedule> getSchedule(String petId, String scheduleId) async {
    final res = await dio.get('/api/v1/pets/$petId/care-schedules/$scheduleId');
    return CareSchedule.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<CareSchedule> updateSchedule(
    String petId,
    String scheduleId,
    CareSchedule schedule,
  ) async {
    final res = await dio.put(
      '/api/v1/pets/$petId/care-schedules/$scheduleId',
      data: schedule.toRequestJson(),
    );
    return CareSchedule.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteSchedule(String petId, String scheduleId) async {
    await dio.delete('/api/v1/pets/$petId/care-schedules/$scheduleId');
  }
}
