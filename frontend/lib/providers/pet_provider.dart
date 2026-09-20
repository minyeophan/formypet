import 'dart:async';
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

const _removedQuickTypeIds = {'bath', 'groom'};

List<String> _removeRemovedQuickTypeIds(List<String> ids) =>
    ids.where((id) => !_removedQuickTypeIds.contains(id)).toList();

class PetState {
  final bool isLoading;
  final String? dataErrorText;
  final String? routineRefreshError;
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
    this.dataErrorText,
    this.routineRefreshError,
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
    String? dataErrorText,
    bool clearDataError = false,
    String? routineRefreshError,
    bool clearRoutineRefreshError = false,
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
    routineRefreshError: clearRoutineRefreshError
        ? null
        : routineRefreshError ?? this.routineRefreshError,
    dataErrorText: clearDataError
        ? null
        : (dataErrorText ?? this.dataErrorText),
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

/// Profile fields are persisted; callers must retry this pet, not create another.
class PetPhotoSaveException implements Exception {
  final String petId;
  const PetPhotoSaveException(this.petId);
  @override
  String toString() => '반려동물 정보는 저장됐지만 사진 업로드에 실패했어요. 다시 시도하거나 사진 없이 완료해 주세요.';
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
  int _session = 0;
  int _dataVersion = 0;
  int _routineMutationVersion = 0;
  int _routineReadVersion = 0;
  int _selectionVersion = 0;
  final _routineWrites = <(int, int, String?), int>{};
  final _routineWriteDrains = <(int, int, String?), Completer<void>>{};
  int get _pendingRoutineWrites => _routineWrites[routineContext] ?? 0;
  void _beginRoutineWrite((int, int, String?) token) {
    _routineWriteDrains.putIfAbsent(token, Completer<void>.new);
    _routineWrites[token] = (_routineWrites[token] ?? 0) + 1;
    _routineMutationVersion++;
  }

  void _endRoutineWrite((int, int, String?) token) {
    final remaining = (_routineWrites[token] ?? 1) - 1;
    if (remaining == 0) {
      _routineWrites.remove(token);
      _routineWriteDrains.remove(token)?.complete();
    } else {
      _routineWrites[token] = remaining;
    }
    if (isRoutineContextCurrent(token)) _routineMutationVersion++;
  }

  int _todayRequest = 0;
  Future<void>? _routineRead;
  (int, int, String?)? _routineReadContext;
  (int, int, String?) get routineContext =>
      (_session, _selectionVersion, state.activePetId);
  bool isRoutineContextCurrent((int, int, String?) token) =>
      mounted && token == routineContext;

  Future<void> reloadRoutines() {
    final token = routineContext;
    if (_routineRead != null && _routineReadContext == token) {
      return _routineRead!;
    }
    _routineReadContext = token;
    late final Future<void> request;
    request = _reloadRoutines(token).whenComplete(() {
      if (identical(_routineRead, request)) _routineRead = null;
    });
    return _routineRead = request;
  }

  Future<void> _reloadRoutines((int, int, String?) token) async {
    if (token.$3 == null) return;
    while (isRoutineContextCurrent(token)) {
      if (_pendingRoutineWrites > 0) {
        await _routineWriteDrains[token]!.future;
        continue;
      }
      final version = _routineMutationVersion;
      final request = ++_routineReadVersion;
      final routines = await _routSvc.getRoutines(token.$3!);
      if (!isRoutineContextCurrent(token)) return;
      if (version != _routineMutationVersion ||
          request != _routineReadVersion ||
          _pendingRoutineWrites > 0) {
        continue;
      }
      state = state.copyWith(routines: routines);
      return;
    }
  }

  Future<void> retryTodayRoutines() async {
    final petId = state.activePetId;
    if (petId != null) await _refreshTodayRoutinesBestEffort(petId);
  }

  bool _isCurrent(int session) => mounted && session == _session;

  bool _isCurrentPet(int session, int version, String petId) =>
      _isCurrent(session) &&
      version == _dataVersion &&
      state.activePetId == petId;

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
    final cleaned = _removeRemovedQuickTypeIds(stored);
    if (!listEquals(stored, cleaned)) {
      await prefs.setStringList('quickTypeIds', cleaned);
    }
    return cleaned;
  }

  Future<void> _initializeQuickTypeIds(
    Future<List<String>> Function() loader,
  ) async {
    try {
      final quickTypeIds = _removeRemovedQuickTypeIds(await loader());
      if (!mounted) return;
      state = state.copyWith(isLoading: false, quickTypeIds: quickTypeIds);
    } catch (error) {
      if (!mounted) return;
      debugPrint('Failed to load quick type ids: $error');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadForAuthenticatedUser() async {
    final session = ++_session;
    _dataVersion++;
    _refreshInFlight = null;
    state = PetState(
      isLoading: true,
      hasOnboarded: false,
      pets: const [],
      records: const [],
      routines: const [],
      todayRoutineItems: const [],
      routineCompletions: const {},
      quickTypeIds: state.quickTypeIds,
    );
    await _preferencesReady;
    if (!_isCurrent(session)) return;
    state = state.copyWith(isLoading: true);
    try {
      final pets = await _petSvc.getPets();
      if (!_isCurrent(session)) return;
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
      if (!_isCurrent(session)) return;
      state = state.copyWith(
        isLoading: false,
        dataErrorText: '반려동물 정보를 불러오지 못했어요. 다시 시도해 주세요.',
      );
      rethrow;
    }
  }

  Future<void> clearForSignedOutUser() async {
    _session++;
    _dataVersion++;
    _refreshInFlight = null;
    if (!mounted) return;
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
    final session = _session;
    final version = ++_dataVersion;
    final routineVersion = _routineMutationVersion;
    final routineWritePending = _pendingRoutineWrites > 0;
    final routineRequest = ++_routineReadVersion;
    final todayRequest = ++_todayRequest;
    state = state.copyWith(isLoading: true, clearDataError: true);
    try {
      final data = await _fetchPetData(petId);
      if (!_isCurrentPet(session, version, petId)) return;
      if (routineWritePending ||
          routineRequest != _routineReadVersion ||
          todayRequest != _todayRequest ||
          routineVersion != _routineMutationVersion ||
          _pendingRoutineWrites > 0) {
        state = state.copyWith(
          records: data.records,
          schedules: data.schedules,
          isLoading: false,
          clearDataError: true,
        );
        unawaited(
          reloadRoutines().catchError((Object error) {
            if (_isCurrentPet(session, version, petId)) {
              state = state.copyWith(dataErrorText: '루틴 목록을 갱신하지 못했어요.');
            }
          }),
        );
        return;
      }
      state = data
          .applyTo(state)
          .copyWith(isLoading: false, clearDataError: true);
    } catch (_) {
      if (!_isCurrentPet(session, version, petId)) return;
      state = state.copyWith(
        isLoading: false,
        dataErrorText: '반려동물 기록을 불러오지 못했어요. 다시 시도해 주세요.',
      );
      rethrow;
    }
  }

  Future<void> refreshPets() {
    final session = _session;
    return _refreshInFlight ??= _refreshPets().whenComplete(() {
      if (_isCurrent(session)) _refreshInFlight = null;
    });
  }

  Future<void> _refreshPets() async {
    final session = _session;
    final version = _dataVersion;
    final pets = await _petSvc.getPets();
    if (!_isCurrent(session) || version != _dataVersion) return;
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
    state = state.copyWith(pets: pets, hasOnboarded: true);
    await setActivePet(nextId);
  }

  Future<void> setActivePet(String petId) async {
    if (!state.pets.any((pet) => pet.id == petId)) {
      throw StateError('Pet not found');
    }
    _selectionVersion++;
    state = state.copyWith(
      clearRoutineRefreshError: true,
      activePetId: petId,
      records: const [],
      routines: const [],
      schedules: const [],
      todayRoutineItems: const [],
      routineCompletions: const {},
      clearTodaySummary: true,
      clearDataError: true,
    );
    await _loadPetData(petId);
  }

  Future<void> retryDataLoad() => state.activePetId == null
      ? loadForAuthenticatedUser()
      : _loadPetData(state.activePetId!);

  Future<bool> activateReminderTarget({
    required String sourceId,
    required bool isSchedule,
    bool Function()? isRequestCurrent,
  }) async {
    final session = _session;
    final version = _dataVersion;
    final pets = await _petSvc.getPets();
    if (!_isCurrent(session) ||
        version != _dataVersion ||
        isRequestCurrent?.call() == false) {
      return false;
    }
    for (final pet in pets) {
      final found = isSchedule
          ? (await _requireScheduleService().getSchedules(
              pet.id,
            )).any((item) => item.id == sourceId && item.petId == pet.id)
          : (await _routSvc.getRoutines(
              pet.id,
            )).any((item) => item.id == sourceId && item.petId == pet.id);
      if (!_isCurrent(session) ||
          version != _dataVersion ||
          isRequestCurrent?.call() == false) {
        return false;
      }
      if (!found) continue;
      state = state.copyWith(pets: pets, hasOnboarded: true);
      await setActivePet(pet.id);
      if (!_isCurrent(session) || state.activePetId != pet.id) return false;
      return isSchedule
          ? state.schedules.any(
              (item) => item.id == sourceId && item.petId == pet.id,
            )
          : state.routines.any(
              (item) => item.id == sourceId && item.petId == pet.id,
            );
    }
    return false;
  }

  // Pet CRUD
  Future<void> addPet(
    Map<String, dynamic> body, {
    PetPhotoUpload? photo,
  }) async {
    final session = _session;
    await _preferencesReady;
    if (!_isCurrent(session)) return;
    final pet = await _petSvc.createPet(body);
    if (!_isCurrent(session)) return;
    state = PetState(
      isLoading: false,
      hasOnboarded: state.hasOnboarded,
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
      final savedPet = await _uploadSavedPetPhoto(pet, photo);
      if (!_isCurrent(session)) return;
      state = state.copyWith(
        pets: state.pets.map((p) => p.id == pet.id ? savedPet : p).toList(),
      );
    }
    try {
      await _loadPetData(pet.id);
    } catch (error) {
      // Creation already succeeded; a refresh failure must not invite duplication.
      debugPrint('Failed to refresh new pet data: $error');
    }
    if (_isCurrent(session)) state = state.copyWith(hasOnboarded: true);
  }

  Future<void> updatePet(
    String petId,
    Map<String, dynamic> body, {
    PetPhotoUpload? photo,
  }) async {
    final session = _session;
    final updated = await _petSvc.updatePet(petId, body);
    if (!_isCurrent(session)) return;
    state = state.copyWith(
      pets: state.pets.map((p) => p.id == petId ? updated : p).toList(),
    );
    if (photo != null) {
      final savedPet = await _uploadSavedPetPhoto(updated, photo);
      if (!_isCurrent(session)) return;
      state = state.copyWith(
        pets: state.pets.map((p) => p.id == petId ? savedPet : p).toList(),
      );
    }
    state = state.copyWith(hasOnboarded: true);
  }

  Future<Pet> _uploadSavedPetPhoto(Pet pet, PetPhotoUpload photo) async {
    try {
      return await _uploadPhoto(pet, photo);
    } catch (_) {
      throw PetPhotoSaveException(pet.id);
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
    final session = _session;
    await _petSvc.deletePet(petId);
    if (!_isCurrent(session)) return;
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
      state = state.copyWith(pets: remaining);
      if (nextId != oldActivePetId) {
        try {
          await setActivePet(nextId);
        } catch (error) {
          // Deletion is committed; the next pet's data can be retried separately.
          debugPrint('Failed to load the next pet after deletion: $error');
        }
      }
    }
  }

  // Record CRUD
  Future<void> addRecord(
    Map<String, dynamic> body, {
    RecordPhotoUpload? photo,
  }) async {
    final session = _session;
    final version = _dataVersion;
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
    if (!_isCurrentPet(session, version, petId)) return;
    state = state.copyWith(records: [...state.records, record]);
  }

  Future<void> updateRecord(String recordId, Map<String, dynamic> body) async {
    final session = _session;
    final version = _dataVersion;
    final petId = state.activePetId!;
    final updated = await _recSvc.updateRecord(petId, recordId, body);
    if (!_isCurrentPet(session, version, petId)) return;
    state = state.copyWith(
      records: state.records
          .map((r) => r.id == recordId ? updated : r)
          .toList(),
    );
  }

  Future<void> deleteRecord(String recordId) async {
    final session = _session;
    final version = _dataVersion;
    final petId = state.activePetId!;
    await _recSvc.deleteRecord(petId, recordId);
    if (!_isCurrentPet(session, version, petId)) return;
    state = state.copyWith(
      records: state.records.where((r) => r.id != recordId).toList(),
    );
  }

  // Routine CRUD
  Future<CareSchedule> addCareSchedule(CareSchedule schedule) async {
    final session = _session;
    final version = _dataVersion;
    final petId = state.activePetId!;
    final scheduleSvc = _requireScheduleService();
    final saved = await scheduleSvc.createSchedule(petId, schedule);
    if (!_isCurrentPet(session, version, petId)) return saved;
    final next = [...state.schedules, saved];
    state = state.copyWith(schedules: next);
    return saved;
  }

  Future<CareSchedule> updateCareSchedule(CareSchedule schedule) async {
    final session = _session;
    final version = _dataVersion;
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
    if (!_isCurrentPet(session, version, petId)) return saved;
    final next = state.schedules
        .map((item) => item.id == saved.id ? saved : item)
        .toList();
    state = state.copyWith(schedules: next);
    return saved;
  }

  Future<void> deleteCareSchedule(String scheduleId) async {
    final session = _session;
    final version = _dataVersion;
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
    if (!_isCurrentPet(session, version, petId)) return;
    final next = state.schedules
        .where((schedule) => schedule.id != scheduleId)
        .toList();
    state = state.copyWith(schedules: next);
  }

  Future<bool> addRoutine(Map<String, dynamic> body) async {
    final token = routineContext;
    final petId = state.activePetId!;
    _beginRoutineWrite(token);
    try {
      final routine = await _routSvc.createRoutine(petId, body);
      if (!isRoutineContextCurrent(token)) return false;
      state = state.copyWith(routines: [...state.routines, routine]);
    } finally {
      _endRoutineWrite(token);
    }
    if (isRoutineContextCurrent(token)) {
      await _refreshTodayRoutinesBestEffort(petId);
    }
    return isRoutineContextCurrent(token);
  }

  Future<bool> updateRoutine(
    String routineId,
    Map<String, dynamic> body,
  ) async {
    final token = routineContext;
    final petId = state.activePetId!;
    _beginRoutineWrite(token);
    try {
      final updated = await _routSvc.updateRoutine(petId, routineId, body);
      if (!isRoutineContextCurrent(token)) return false;
      state = state.copyWith(
        routines: state.routines.any((r) => r.id == routineId)
            ? state.routines
                  .map((r) => r.id == routineId ? updated : r)
                  .toList()
            : [...state.routines, updated],
      );
    } finally {
      _endRoutineWrite(token);
    }
    if (isRoutineContextCurrent(token)) {
      unawaited(_refreshTodayRoutinesBestEffort(petId));
    }
    return isRoutineContextCurrent(token);
  }

  Future<bool> deleteRoutine(String routineId) async {
    final token = routineContext;
    final petId = state.activePetId!;
    _beginRoutineWrite(token);
    try {
      await _routSvc.deleteRoutine(petId, routineId);
      if (!isRoutineContextCurrent(token)) return false;
      final completions = Map<String, CompletionStatus>.from(
        state.routineCompletions,
      )..removeWhere((key, _) => key.startsWith('$routineId:'));
      state = state.copyWith(
        routines: state.routines.where((r) => r.id != routineId).toList(),
        todayRoutineItems: state.todayRoutineItems
            .where((item) => item.routine.id != routineId)
            .toList(),
        routineCompletions: completions,
      );
      state = state.copyWith(todaySummary: _todaySummaryFrom(completions));
    } finally {
      _endRoutineWrite(token);
    }
    if (isRoutineContextCurrent(token)) {
      unawaited(_refreshTodayRoutinesBestEffort(petId));
    }
    return isRoutineContextCurrent(token);
  }

  Future<void> toggleRoutineCompletion(String routineId, String date) async {
    final session = _session;
    final version = _dataVersion;
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
    if (!_isCurrentPet(session, version, petId)) return;
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
    final token = routineContext;
    final request = ++_todayRequest;
    final routineVersion = _routineMutationVersion;
    if (_pendingRoutineWrites > 0) return;
    try {
      final todayData = await _routSvc.getTodayRoutines(petId);
      if (!isRoutineContextCurrent(token) ||
          request != _todayRequest ||
          routineVersion != _routineMutationVersion ||
          _pendingRoutineWrites > 0) {
        return;
      }

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
        clearRoutineRefreshError: true,
        todayRoutineItems: todayData.items,
        todaySummary: todayData.summary,
        routineCompletions: completions,
      );
    } catch (error) {
      if (isRoutineContextCurrent(token) &&
          request == _todayRequest &&
          routineVersion == _routineMutationVersion) {
        state = state.copyWith(
          routineRefreshError: '저장은 완료됐지만 오늘 루틴을 갱신하지 못했어요',
        );
      }
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
    final cleaned = _removeRemovedQuickTypeIds(ids);
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
