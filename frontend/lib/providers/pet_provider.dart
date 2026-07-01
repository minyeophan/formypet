import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet.dart';
import '../models/activity_record.dart';
import '../models/care_schedule.dart';
import '../models/routine.dart';
import '../services/pet_service.dart';
import '../services/media_service.dart';
import '../services/record_service.dart';
import '../services/routine_service.dart';
import '../services/care_schedule_service.dart';
import '../core/record_utils.dart';

const _deprecatedQuickTypeIds = {'play', 'sleep', 'checkup'};

List<String> _removeDeprecatedQuickTypeIds(List<String> ids) =>
    ids.where((id) => !_deprecatedQuickTypeIds.contains(id)).toList();

class PetState {
  final bool isLoading;
  final bool hasOnboarded;
  final List<Pet> pets;
  final String? activePetId;
  final List<ActivityRecord> records;
  final List<Routine> routines;
  final List<CareSchedule> schedules;
  final List<TodayRoutineItem> todayRoutineItems;
  // completionKey = "routineId:date" → CompletionStatus
  final Map<String, CompletionStatus> routineCompletions;
  // Today's routine summary
  final TodayRoutineSummary? todaySummary;
  // Quick type IDs (persisted)
  final List<String> quickTypeIds;

  const PetState({
    required this.isLoading,
    required this.hasOnboarded,
    required this.pets,
    this.activePetId,
    required this.records,
    required this.routines,
    this.schedules = const [],
    required this.todayRoutineItems,
    required this.routineCompletions,
    this.todaySummary,
    required this.quickTypeIds,
  });

  Pet? get activePet => pets.where((p) => p.id == activePetId).firstOrNull;

  // clearActivePetId: true이면 activePetId를 null로 강제 설정
  PetState copyWith({
    bool? isLoading,
    bool? hasOnboarded,
    List<Pet>? pets,
    String? activePetId,
    bool clearActivePetId = false,
    List<ActivityRecord>? records,
    List<Routine>? routines,
    List<CareSchedule>? schedules,
    List<TodayRoutineItem>? todayRoutineItems,
    Map<String, CompletionStatus>? routineCompletions,
    TodayRoutineSummary? todaySummary,
    bool clearTodaySummary = false,
    List<String>? quickTypeIds,
  }) => PetState(
    isLoading: isLoading ?? this.isLoading,
    hasOnboarded: hasOnboarded ?? this.hasOnboarded,
    pets: pets ?? this.pets,
    activePetId: clearActivePetId ? null : (activePetId ?? this.activePetId),
    records: records ?? this.records,
    routines: routines ?? this.routines,
    schedules: schedules ?? this.schedules,
    todayRoutineItems: todayRoutineItems ?? this.todayRoutineItems,
    routineCompletions: routineCompletions ?? this.routineCompletions,
    todaySummary: clearTodaySummary
        ? null
        : (todaySummary ?? this.todaySummary),
    quickTypeIds: quickTypeIds ?? this.quickTypeIds,
  );
}

class PetPhotoUpload {
  final Uint8List bytes;
  final String filename;

  const PetPhotoUpload({required this.bytes, required this.filename});
}

class RecordPhotoUpload {
  final Uint8List bytes;
  final String filename;

  const RecordPhotoUpload({required this.bytes, required this.filename});
}

class PetNotifier extends StateNotifier<PetState> {
  final PetService _petSvc;
  final MediaService _mediaSvc;
  final RecordService _recSvc;
  final RoutineService _routSvc;
  final CareScheduleService? _scheduleSvc;
  late final Future<void> _preferencesReady;
  Future<void>? _refreshInFlight;

  PetNotifier(
    this._petSvc,
    this._recSvc,
    this._routSvc, [
    MediaService? mediaSvc,
    CareScheduleService? scheduleSvc,
  ]) : _mediaSvc = mediaSvc ?? MediaService(),
       _scheduleSvc = scheduleSvc,
       super(
         PetState(
           isLoading: true,
           hasOnboarded: false,
           pets: const [],
           records: const [],
           routines: const [],
           schedules: const [],
           todayRoutineItems: const [],
           routineCompletions: const {},
           quickTypeIds: kDefaultQuickIds,
         ),
       ) {
    _preferencesReady = _initializeQuickTypeIds(_readStoredQuickTypeIds);
  }

  PetNotifier.test(super.initialState)
    : _petSvc = PetService(),
      _mediaSvc = MediaService(),
      _recSvc = RecordService(),
      _routSvc = RoutineService(),
      _scheduleSvc = null {
    _preferencesReady = Future.value();
  }

  PetNotifier.testWithServices(
    super.initialState, {
    PetService? petService,
    RecordService? recordService,
    RoutineService? routineService,
    MediaService? mediaService,
    CareScheduleService? scheduleService,
    Future<List<String>> Function()? quickTypeIdsLoader,
  }) : _petSvc = petService ?? PetService(),
       _mediaSvc = mediaService ?? MediaService(),
       _recSvc = recordService ?? RecordService(),
       _routSvc = routineService ?? RoutineService(),
       _scheduleSvc = scheduleService {
    _preferencesReady = quickTypeIdsLoader == null
        ? Future.value()
        : _initializeQuickTypeIds(quickTypeIdsLoader);
  }

  Future<List<String>> _readStoredQuickTypeIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('quickTypeIds') ?? kDefaultQuickIds;
    final cleaned = _removeDeprecatedQuickTypeIds(stored);
    if (!listEquals(stored, cleaned)) {
      await prefs.setStringList('quickTypeIds', cleaned);
    }
    return cleaned;
  }

  Future<void> _initializeQuickTypeIds(
    Future<List<String>> Function() loader,
  ) async {
    try {
      final quickTypeIds = _removeDeprecatedQuickTypeIds(await loader());
      state = state.copyWith(isLoading: false, quickTypeIds: quickTypeIds);
    } catch (error) {
      debugPrint('Failed to load quick type ids: $error');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadForAuthenticatedUser() async {
    await _preferencesReady;
    state = state.copyWith(isLoading: true);
    try {
      final pets = await _petSvc.getPets();
      final activePetId = pets.isNotEmpty ? pets.first.id : null;
      if (activePetId == null) {
        state = PetState(
          isLoading: false,
          hasOnboarded: false,
          pets: const [],
          records: const [],
          routines: const [],
          schedules: const [],
          todayRoutineItems: const [],
          routineCompletions: const {},
          quickTypeIds: state.quickTypeIds,
        );
        return;
      }

      state = PetState(
        isLoading: false,
        hasOnboarded: true,
        pets: pets,
        activePetId: activePetId,
        records: const [],
        routines: const [],
        schedules: const [],
        todayRoutineItems: const [],
        routineCompletions: const {},
        quickTypeIds: state.quickTypeIds,
      );
      await _loadPetData(activePetId);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> clearForSignedOutUser() async {
    state = PetState(
      isLoading: false,
      hasOnboarded: false,
      pets: const [],
      records: const [],
      routines: const [],
      schedules: const [],
      todayRoutineItems: const [],
      routineCompletions: const {},
      quickTypeIds: state.quickTypeIds,
    );
  }

  Future<_PetData> _fetchPetData(String petId) async {
    final results = await Future.wait([
      _recSvc.getRecords(petId),
      _routSvc.getRoutines(petId),
      _routSvc.getTodayRoutines(petId),
      _scheduleSvc?.getSchedules(petId) ?? Future.value(const <CareSchedule>[]),
    ]);

    final records = results[0] as List<ActivityRecord>;
    final routines = results[1] as List<Routine>;
    final todayData = results[2] as TodayRoutineData;
    final schedules = results[3] as List<CareSchedule>;

    // Build completion map from actual completion status returned by backend
    // completionKey: "routineId:scheduledDate"
    final completions = <String, CompletionStatus>{};
    for (final item in todayData.items) {
      final key = '${item.routine.id}:${item.completion.scheduledDate}';
      completions[key] = item.completion.status;
    }

    return _PetData(
      records: records,
      routines: routines,
      schedules: schedules,
      todayRoutineItems: todayData.items,
      todaySummary: todayData.summary,
      routineCompletions: completions,
    );
  }

  Future<void> _loadPetData(String petId) async {
    final data = await _fetchPetData(petId);
    if (state.activePetId != petId) return;
    state = data.applyTo(state);
  }

  Future<void> refreshPets() =>
      _refreshInFlight ??= _refreshPets().whenComplete(() {
        _refreshInFlight = null;
      });

  Future<void> _refreshPets() async {
    final pets = await _petSvc.getPets();
    if (pets.isEmpty) {
      state = PetState(
        isLoading: false,
        hasOnboarded: false,
        pets: const [],
        records: const [],
        routines: const [],
        schedules: const [],
        todayRoutineItems: const [],
        routineCompletions: const {},
        quickTypeIds: state.quickTypeIds,
      );
      return;
    }

    final activeId = state.activePetId;
    if (activeId != null && pets.any((pet) => pet.id == activeId)) {
      state = state.copyWith(pets: pets, hasOnboarded: true);
      return;
    }

    final nextId = pets.first.id;
    try {
      final data = await _fetchPetData(nextId);
      state = data.applyTo(
        state.copyWith(pets: pets, activePetId: nextId, hasOnboarded: true),
      );
    } catch (_) {
      state = state.copyWith(
        pets: pets,
        activePetId: nextId,
        hasOnboarded: true,
        records: const [],
        routines: const [],
        schedules: const [],
        todayRoutineItems: const [],
        routineCompletions: const {},
        clearTodaySummary: true,
      );
      rethrow;
    }
  }

  Future<void> setActivePet(String petId) async {
    state = state.copyWith(activePetId: petId);
    await _loadPetData(petId);
  }

  // Pet CRUD
  Future<void> addPet(
    Map<String, dynamic> body, {
    PetPhotoUpload? photo,
  }) async {
    await _preferencesReady;
    final pet = await _petSvc.createPet(body);
    state = PetState(
      isLoading: false,
      hasOnboarded: true,
      pets: [...state.pets, pet],
      activePetId: pet.id,
      records: const [],
      routines: const [],
      schedules: const [],
      todayRoutineItems: const [],
      routineCompletions: const {},
      quickTypeIds: state.quickTypeIds,
    );
    if (photo != null) {
      final savedPet = await _uploadPhoto(pet, photo);
      state = state.copyWith(
        pets: state.pets.map((p) => p.id == pet.id ? savedPet : p).toList(),
      );
    }
    await _loadPetData(pet.id);
  }

  Future<void> updatePet(
    String petId,
    Map<String, dynamic> body, {
    PetPhotoUpload? photo,
  }) async {
    final updated = await _petSvc.updatePet(petId, body);
    state = state.copyWith(
      pets: state.pets.map((p) => p.id == petId ? updated : p).toList(),
    );
    if (photo != null) {
      final savedPet = await _uploadPhoto(updated, photo);
      state = state.copyWith(
        pets: state.pets.map((p) => p.id == petId ? savedPet : p).toList(),
      );
    }
  }

  Future<Pet> _uploadPhoto(Pet pet, PetPhotoUpload photo) async {
    final url = await _mediaSvc.uploadPetPhoto(
      petId: pet.id,
      bytes: photo.bytes,
      filename: photo.filename,
    );
    return pet.copyWith(profileImageUrl: url);
  }

  Future<void> deletePet(String petId) async {
    await _petSvc.deletePet(petId);
    final oldActivePetId = state.activePetId;
    final remaining = state.pets.where((p) => p.id != petId).toList();
    if (remaining.isEmpty) {
      state = PetState(
        isLoading: false,
        hasOnboarded: false,
        pets: const [],
        records: const [],
        routines: const [],
        schedules: const [],
        todayRoutineItems: const [],
        routineCompletions: const {},
        quickTypeIds: state.quickTypeIds,
      );
    } else {
      final nextId = remaining.any((p) => p.id == state.activePetId)
          ? state.activePetId!
          : remaining.first.id;
      state = state.copyWith(pets: remaining, activePetId: nextId);
      if (nextId != oldActivePetId) {
        await _loadPetData(nextId);
      }
    }
  }

  // Record CRUD
  Future<void> addRecord(
    Map<String, dynamic> body, {
    RecordPhotoUpload? photo,
  }) async {
    final petId = state.activePetId!;
    final record = photo == null
        ? await _recSvc.createRecord(petId, body)
        : await _recSvc.createRecordWithMediaBytes(
            petId: petId,
            body: body,
            files: [
              RecordMediaUpload(bytes: photo.bytes, filename: photo.filename),
            ],
          );
    state = state.copyWith(records: [...state.records, record]);
  }

  Future<void> updateRecord(String recordId, Map<String, dynamic> body) async {
    final petId = state.activePetId!;
    final updated = await _recSvc.updateRecord(petId, recordId, body);
    state = state.copyWith(
      records: state.records
          .map((r) => r.id == recordId ? updated : r)
          .toList(),
    );
  }

  Future<void> deleteRecord(String recordId) async {
    final petId = state.activePetId!;
    await _recSvc.deleteRecord(petId, recordId);
    state = state.copyWith(
      records: state.records.where((r) => r.id != recordId).toList(),
    );
  }

  // Routine CRUD
  Future<CareSchedule> addCareSchedule(CareSchedule schedule) async {
    final petId = state.activePetId!;
    final scheduleSvc = _requireScheduleService();
    final saved = await scheduleSvc.createSchedule(petId, schedule);
    final next = [...state.schedules, saved];
    state = state.copyWith(schedules: next);
    return saved;
  }

  Future<CareSchedule> updateCareSchedule(CareSchedule schedule) async {
    final petId = state.activePetId;
    final scheduleSvc = _requireScheduleService();
    if (petId == null || schedule.petId != petId) {
      throw StateError('Care schedule not found');
    }
    final index = state.schedules.indexWhere(
      (candidate) => candidate.id == schedule.id && candidate.petId == petId,
    );
    if (index < 0) {
      throw StateError('Care schedule not found');
    }
    final saved = await scheduleSvc.updateSchedule(
      petId,
      schedule.id,
      schedule,
    );
    final next = [...state.schedules];
    next[index] = saved;
    state = state.copyWith(schedules: next);
    return saved;
  }

  Future<void> deleteCareSchedule(String scheduleId) async {
    final petId = state.activePetId;
    if (petId == null) {
      throw StateError('Care schedule not found');
    }
    final scheduleSvc = _requireScheduleService();
    final exists = state.schedules.any(
      (schedule) => schedule.id == scheduleId && schedule.petId == petId,
    );
    if (!exists) {
      throw StateError('Care schedule not found');
    }
    await scheduleSvc.deleteSchedule(petId, scheduleId);
    final next = state.schedules
        .where((schedule) => schedule.id != scheduleId)
        .toList();
    state = state.copyWith(schedules: next);
  }

  Future<void> addRoutine(Map<String, dynamic> body) async {
    final petId = state.activePetId!;
    final routine = await _routSvc.createRoutine(petId, body);
    state = state.copyWith(routines: [...state.routines, routine]);
    await _refreshTodayRoutinesBestEffort(petId);
  }

  Future<void> updateRoutine(
    String routineId,
    Map<String, dynamic> body,
  ) async {
    final petId = state.activePetId!;
    final updated = await _routSvc.updateRoutine(petId, routineId, body);
    state = state.copyWith(
      routines: state.routines
          .map((r) => r.id == routineId ? updated : r)
          .toList(),
    );
    await _refreshTodayRoutinesBestEffort(petId);
  }

  Future<void> deleteRoutine(String routineId) async {
    final petId = state.activePetId!;
    await _routSvc.deleteRoutine(petId, routineId);
    final completions = Map<String, CompletionStatus>.from(
      state.routineCompletions,
    )..removeWhere((key, _) => key.startsWith('$routineId:'));
    state = state.copyWith(
      routines: state.routines.where((r) => r.id != routineId).toList(),
      routineCompletions: completions,
    );
    await _refreshTodayRoutinesBestEffort(petId);
  }

  Future<void> toggleRoutineCompletion(String routineId, String date) async {
    final petId = state.activePetId!;
    final key = '$routineId:$date';
    final current = state.routineCompletions[key] ?? CompletionStatus.pending;
    final next = current == CompletionStatus.completed
        ? CompletionStatus.pending
        : CompletionStatus.completed;

    final completion = await _routSvc.patchCompletion(
      petId: petId,
      routineId: routineId,
      date: date,
      status: next,
    );
    final newMap = Map<String, CompletionStatus>.from(state.routineCompletions);
    newMap[key] = completion.status;
    final isTodayItem = state.todayRoutineItems.any(
      (item) =>
          item.routine.id == routineId && item.completion.scheduledDate == date,
    );
    state = state.copyWith(
      routineCompletions: newMap,
      todaySummary: isTodayItem ? _todaySummaryFrom(newMap) : null,
    );
  }

  Future<void> _refreshTodayRoutinesBestEffort(String petId) async {
    try {
      final todayData = await _routSvc.getTodayRoutines(petId);
      if (state.activePetId != petId) return;

      final completions = Map<String, CompletionStatus>.from(
        state.routineCompletions,
      );
      for (final item in state.todayRoutineItems) {
        completions.remove(_completionKey(item));
      }
      for (final item in todayData.items) {
        completions[_completionKey(item)] = item.completion.status;
      }
      state = state.copyWith(
        todayRoutineItems: todayData.items,
        todaySummary: todayData.summary,
        routineCompletions: completions,
      );
    } catch (error) {
      debugPrint('Failed to refresh today routines: $error');
    }
  }

  TodayRoutineSummary _todaySummaryFrom(
    Map<String, CompletionStatus> completions,
  ) {
    final total = state.todayRoutineItems.length;
    final done = state.todayRoutineItems
        .where(
          (item) =>
              completions[_completionKey(item)] == CompletionStatus.completed,
        )
        .length;
    final rate = total == 0
        ? 0.0
        : double.parse((done / total * 100).toStringAsFixed(1));
    return TodayRoutineSummary(total: total, done: done, rate: rate);
  }

  String _completionKey(TodayRoutineItem item) =>
      '${item.routine.id}:${item.completion.scheduledDate}';

  CareScheduleService _requireScheduleService() {
    final scheduleSvc = _scheduleSvc;
    if (scheduleSvc == null) {
      throw StateError('Care schedule service is required');
    }
    return scheduleSvc;
  }

  // QuickTypeIds persistence
  Future<void> setQuickTypeIds(List<String> ids) async {
    final cleaned = _removeDeprecatedQuickTypeIds(ids);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('quickTypeIds', cleaned);
    state = state.copyWith(quickTypeIds: cleaned);
  }
}

class _PetData {
  final List<ActivityRecord> records;
  final List<Routine> routines;
  final List<CareSchedule> schedules;
  final List<TodayRoutineItem> todayRoutineItems;
  final Map<String, CompletionStatus> routineCompletions;
  final TodayRoutineSummary? todaySummary;

  const _PetData({
    required this.records,
    required this.routines,
    required this.schedules,
    required this.todayRoutineItems,
    required this.routineCompletions,
    required this.todaySummary,
  });

  PetState applyTo(PetState state) => state.copyWith(
    records: records,
    routines: routines,
    schedules: schedules,
    todayRoutineItems: todayRoutineItems,
    routineCompletions: routineCompletions,
    todaySummary: todaySummary,
    clearTodaySummary: todaySummary == null,
  );
}

final petServiceProvider = Provider<PetService>((_) => PetService());
final recordServiceProvider = Provider<RecordService>((_) => RecordService());
final routineServiceProvider = Provider<RoutineService>(
  (_) => RoutineService(),
);
final careScheduleServiceProvider = Provider<CareScheduleService>(
  (_) => CareScheduleService(),
);

final latestPetWeightProvider = FutureProvider.family<ActivityRecord?, String>((
  ref,
  petId,
) async {
  final records = await ref
      .read(recordServiceProvider)
      .getRecords(petId, typeId: 'weight');
  final weightRecords = records
      .where((record) => _weightRecordValue(record) != null)
      .toList();
  weightRecords.sort(_compareRecordsNewestFirst);
  return weightRecords.firstOrNull;
});

final petProvider = StateNotifierProvider<PetNotifier, PetState>((ref) {
  return PetNotifier(
    ref.read(petServiceProvider),
    ref.read(recordServiceProvider),
    ref.read(routineServiceProvider),
    null,
    ref.read(careScheduleServiceProvider),
  );
});

Object? _weightRecordValue(ActivityRecord record) =>
    record.detail['weight'] ?? record.detail['value'];

int _compareRecordsNewestFirst(ActivityRecord a, ActivityRecord b) {
  final dateCompare = b.date.compareTo(a.date);
  if (dateCompare != 0) return dateCompare;

  final timeCompare = (b.time ?? '').compareTo(a.time ?? '');
  if (timeCompare != 0) return timeCompare;

  final aId = int.tryParse(a.id);
  final bId = int.tryParse(b.id);
  if (aId != null && bId != null) {
    return bId.compareTo(aId);
  }
  return b.id.compareTo(a.id);
}
