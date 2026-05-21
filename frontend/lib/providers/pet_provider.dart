import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet.dart';
import '../models/activity_record.dart';
import '../models/routine.dart';
import '../services/pet_service.dart';
import '../services/media_service.dart';
import '../services/record_service.dart';
import '../services/routine_service.dart';
import '../core/record_utils.dart';

class PetState {
  final bool isLoading;
  final bool hasOnboarded;
  final List<Pet> pets;
  final String? activePetId;
  final List<ActivityRecord> records;
  final List<Routine> routines;
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
  late final Future<void> _preferencesReady;

  PetNotifier(
    this._petSvc,
    this._recSvc,
    this._routSvc, [
    MediaService? mediaSvc,
  ]) : _mediaSvc = mediaSvc ?? MediaService(),
       super(
         PetState(
           isLoading: true,
           hasOnboarded: false,
           pets: const [],
           records: const [],
           routines: const [],
           todayRoutineItems: const [],
           routineCompletions: const {},
           quickTypeIds: kDefaultQuickIds,
         ),
       ) {
    _preferencesReady = _loadQuickTypeIds();
  }

  PetNotifier.test(super.initialState)
    : _petSvc = PetService(),
      _mediaSvc = MediaService(),
      _recSvc = RecordService(),
      _routSvc = RoutineService() {
    _preferencesReady = Future.value();
  }

  Future<void> _loadQuickTypeIds() async {
    final prefs = await SharedPreferences.getInstance();
    final savedQuickIds =
        prefs.getStringList('quickTypeIds') ?? kDefaultQuickIds;
    state = state.copyWith(isLoading: false, quickTypeIds: savedQuickIds);
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
    await _preferencesReady;
    state = PetState(
      isLoading: false,
      hasOnboarded: false,
      pets: const [],
      records: const [],
      routines: const [],
      todayRoutineItems: const [],
      routineCompletions: const {},
      quickTypeIds: state.quickTypeIds,
    );
  }

  Future<void> _loadPetData(String petId) async {
    final results = await Future.wait([
      _recSvc.getRecords(petId),
      _routSvc.getRoutines(petId),
      _routSvc.getTodayRoutines(petId),
    ]);

    final records = results[0] as List<ActivityRecord>;
    final routines = results[1] as List<Routine>;
    final todayData = results[2] as TodayRoutineData;

    // Build completion map from actual completion status returned by backend
    // completionKey: "routineId:scheduledDate"
    final completions = <String, CompletionStatus>{};
    for (final item in todayData.items) {
      final key = '${item.routine.id}:${item.completion.scheduledDate}';
      completions[key] = item.completion.status;
    }

    state = state.copyWith(
      records: records,
      routines: routines,
      todayRoutineItems: todayData.items,
      todaySummary: todayData.summary,
      routineCompletions: completions,
    );
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
  Future<void> addRoutine(Map<String, dynamic> body) async {
    final petId = state.activePetId!;
    final routine = await _routSvc.createRoutine(petId, body);
    state = state.copyWith(routines: [...state.routines, routine]);
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
  }

  Future<void> deleteRoutine(String routineId) async {
    final petId = state.activePetId!;
    await _routSvc.deleteRoutine(petId, routineId);
    state = state.copyWith(
      routines: state.routines.where((r) => r.id != routineId).toList(),
    );
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
    state = state.copyWith(routineCompletions: newMap);
  }

  // QuickTypeIds persistence
  Future<void> setQuickTypeIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('quickTypeIds', ids);
    state = state.copyWith(quickTypeIds: ids);
  }
}

final petServiceProvider = Provider<PetService>((_) => PetService());
final recordServiceProvider = Provider<RecordService>((_) => RecordService());
final routineServiceProvider = Provider<RoutineService>(
  (_) => RoutineService(),
);

final petProvider = StateNotifierProvider<PetNotifier, PetState>((ref) {
  return PetNotifier(
    ref.read(petServiceProvider),
    ref.read(recordServiceProvider),
    ref.read(routineServiceProvider),
  );
});
