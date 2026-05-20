import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/record_service.dart';
import 'package:frontend/services/routine_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'loadForAuthenticatedUser sets hasOnboarded false when server has no pets',
    () async {
      final notifier = PetNotifier(
        _FakePetService(pets: const []),
        _FakeRecordService(),
        _FakeRoutineService(),
      );

      await notifier.loadForAuthenticatedUser();

      expect(notifier.state.hasOnboarded, isFalse);
      expect(notifier.state.pets, isEmpty);
      expect(notifier.state.activePetId, isNull);
    },
  );

  test(
    'loadForAuthenticatedUser sets hasOnboarded true when server has pets',
    () async {
      final pet = _pet('1');
      final notifier = PetNotifier(
        _FakePetService(pets: [pet]),
        _FakeRecordService(),
        _FakeRoutineService(),
      );

      await notifier.loadForAuthenticatedUser();

      expect(notifier.state.hasOnboarded, isTrue);
      expect(notifier.state.pets, [pet]);
      expect(notifier.state.activePetId, '1');
    },
  );

  test('clearForSignedOutUser clears account-scoped pet data', () async {
    final pet = _pet('1');
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      _FakeRecordService(records: [_record('r1', pet.id)]),
      _FakeRoutineService(routines: [_routine('rt1', pet.id)]),
    );
    await notifier.loadForAuthenticatedUser();
    await notifier.setQuickTypeIds(const ['meal', 'water']);

    await notifier.clearForSignedOutUser();

    expect(notifier.state.hasOnboarded, isFalse);
    expect(notifier.state.pets, isEmpty);
    expect(notifier.state.activePetId, isNull);
    expect(notifier.state.records, isEmpty);
    expect(notifier.state.routines, isEmpty);
    expect(notifier.state.routineCompletions, isEmpty);
    expect(notifier.state.todaySummary, isNull);
    expect(notifier.state.quickTypeIds, const ['meal', 'water']);
  });

  test(
    'addPet makes the newly created pet active and loads its data',
    () async {
      final firstPet = _pet('1');
      final newPet = _pet('2');
      final recordService = _FakeRecordService();
      final notifier = PetNotifier(
        _FakePetService(pets: [firstPet], createdPet: newPet),
        recordService,
        _FakeRoutineService(),
      );
      await notifier.loadForAuthenticatedUser();

      await notifier.addPet({'name': 'Bori'});

      expect(notifier.state.activePetId, '2');
      expect(recordService.loadedPetIds.last, '2');
    },
  );
}

Pet _pet(String id) => Pet(
  id: id,
  name: 'Pet $id',
  species: 'dog',
  birthDate: '2022-03-15',
  accentColor: '#F4A460',
  bgLight: '#FFF8F0',
);

ActivityRecord _record(String id, String petId) =>
    ActivityRecord(id: id, petId: petId, typeId: 'water', date: '2026-05-18');

Routine _routine(String id, String petId) => Routine(
  id: id,
  petId: petId,
  typeId: 'water',
  repeatType: 'daily',
  times: const [],
  days: const [],
  startDate: '2026-05-18',
);

class _FakePetService extends PetService {
  _FakePetService({required this.pets, this.createdPet});

  final List<Pet> pets;
  final Pet? createdPet;

  @override
  Future<List<Pet>> getPets() async => pets;

  @override
  Future<Pet> createPet(Map<String, dynamic> body) async =>
      createdPet ?? _pet('created');
}

class _FakeRecordService extends RecordService {
  _FakeRecordService({this.records = const []});

  final List<ActivityRecord> records;
  final loadedPetIds = <String>[];

  @override
  Future<List<ActivityRecord>> getRecords(
    String petId, {
    String? date,
    String? typeId,
    int? limit,
  }) async {
    loadedPetIds.add(petId);
    return records;
  }
}

class _FakeRoutineService extends RoutineService {
  _FakeRoutineService({this.routines = const []});

  final List<Routine> routines;

  @override
  Future<List<Routine>> getRoutines(String petId) async => routines;

  @override
  Future<TodayRoutineData> getTodayRoutines(String petId) async =>
      const TodayRoutineData(
        items: [],
        summary: TodayRoutineSummary(total: 0, done: 0, rate: 0),
      );
}
