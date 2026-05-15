import '../core/api_client.dart';
import '../models/routine.dart';

class RoutineService {
  Future<List<Routine>> getRoutines(String petId) async {
    final res = await dio.get('/api/v1/pets/$petId/routines');
    final list = unwrap(res) as List<dynamic>;
    return list.map((e) => Routine.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Routine> createRoutine(String petId, Map<String, dynamic> body) async {
    final res = await dio.post('/api/v1/pets/$petId/routines', data: body);
    return Routine.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<Routine> updateRoutine(
      String petId, String routineId, Map<String, dynamic> body) async {
    final res =
        await dio.put('/api/v1/pets/$petId/routines/$routineId', data: body);
    return Routine.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteRoutine(String petId, String routineId) async {
    await dio.delete('/api/v1/pets/$petId/routines/$routineId');
  }

  // Backend returns: { routines: [ { routine: {...}, completion: {...} } ], summary: {...} }
  Future<TodayRoutineData> getTodayRoutines(String petId) async {
    final res = await dio.get('/api/v1/pets/$petId/routines/today');
    final data = unwrap(res) as Map<String, dynamic>;
    final items = (data['routines'] as List<dynamic>)
        .map((e) => TodayRoutineItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final summary =
        TodayRoutineSummary.fromJson(data['summary'] as Map<String, dynamic>);
    return TodayRoutineData(items: items, summary: summary);
  }

  Future<RoutineCompletion> patchCompletion({
    required String petId,
    required String routineId,
    required String date,
    required CompletionStatus status,
  }) async {
    final statusStr = status.name.toUpperCase();
    final res = await dio.patch(
        '/api/v1/pets/$petId/routines/$routineId/completions/$date',
        data: {'status': statusStr});
    return RoutineCompletion.fromJson(unwrap(res) as Map<String, dynamic>);
  }
}
