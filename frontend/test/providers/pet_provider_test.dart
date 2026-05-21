import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/services/media_service.dart';
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
      final routine = _routine('rt1', pet.id);
      final todayItem = _todayRoutineItem(
        routine: routine,
        date: '2026-05-21',
        status: CompletionStatus.pending,
      );
      final notifier = PetNotifier(
        _FakePetService(pets: [pet]),
        _FakeRecordService(),
        _FakeRoutineService(routines: [routine], todayItems: [todayItem]),
      );

      await notifier.loadForAuthenticatedUser();

      expect(notifier.state.hasOnboarded, isTrue);
      expect(notifier.state.pets, [pet]);
      expect(notifier.state.activePetId, '1');
      expect(notifier.state.todayRoutineItems, [todayItem]);
      expect(notifier.state.routineCompletions, {
        'rt1:2026-05-21': CompletionStatus.pending,
      });
    },
  );

  test('toggleRoutineCompletion keeps completion map behavior', () async {
    final pet = _pet('1');
    final routine = _routine('rt1', pet.id);
    final routineService = _FakeRoutineService(
      routines: [routine],
      todayItems: [
        _todayRoutineItem(
          routine: routine,
          date: '2026-05-21',
          status: CompletionStatus.pending,
        ),
      ],
    );
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      _FakeRecordService(),
      routineService,
    );
    await notifier.loadForAuthenticatedUser();

    await notifier.toggleRoutineCompletion('rt1', '2026-05-21');

    expect(routineService.patchRequests, [
      ('1', 'rt1', '2026-05-21', CompletionStatus.completed),
    ]);
    expect(notifier.state.routineCompletions, {
      'rt1:2026-05-21': CompletionStatus.completed,
    });
  });

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
    expect(notifier.state.todayRoutineItems, isEmpty);
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

  test(
    'addPet uploads optional profile photo and updates local pet url',
    () async {
      final newPet = _pet('2');
      final mediaService = _FakeMediaService(uploadedUrl: '/api/v1/media/9');
      final notifier = PetNotifier(
        _FakePetService(pets: const [], createdPet: newPet),
        _FakeRecordService(),
        _FakeRoutineService(),
        mediaService,
      );

      await notifier.addPet(
        {'name': 'Bori'},
        photo: PetPhotoUpload(
          bytes: Uint8List.fromList([1, 2]),
          filename: 'bori.png',
        ),
      );

      expect(mediaService.uploadedPetIds, ['2']);
      expect(notifier.state.pets.single.profileImageUrl, '/api/v1/media/9');
    },
  );

  test('addRecord creates record and appends it locally', () async {
    final pet = _pet('1');
    final recordService = _FakeRecordService(createdRecord: _record('r1', '1'));
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      recordService,
      _FakeRoutineService(),
    );
    await notifier.loadForAuthenticatedUser();

    await notifier.addRecord({'typeId': 'meal', 'date': '2026-05-21'});

    expect(recordService.createdBodies, [
      {'typeId': 'meal', 'date': '2026-05-21'},
    ]);
    expect(notifier.state.records.single.id, 'r1');
  });

  test(
    'addRecord uploads optional record photo and appends refreshed record',
    () async {
      final pet = _pet('1');
      final recordService = _FakeRecordService(
        createdRecord: const ActivityRecord(
          id: 'meal-1',
          petId: '1',
          typeId: 'meal',
          date: '2026-05-21',
          mediaUrls: ['/api/v1/media/1'],
        ),
      );
      final notifier = PetNotifier(
        _FakePetService(pets: [pet]),
        recordService,
        _FakeRoutineService(),
      );
      await notifier.loadForAuthenticatedUser();

      await notifier.addRecord(
        {'typeId': 'meal', 'date': '2026-05-21'},
        photo: RecordPhotoUpload(
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'meal.png',
        ),
      );

      expect(recordService.createdMediaBodies, [
        {'typeId': 'meal', 'date': '2026-05-21'},
      ]);
      expect(recordService.uploadedFilenames, ['meal.png']);
      expect(notifier.state.records.single.mediaUrls, ['/api/v1/media/1']);
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

TodayRoutineItem _todayRoutineItem({
  required Routine routine,
  required String date,
  required CompletionStatus status,
}) => TodayRoutineItem(
  routine: routine,
  completion: RoutineCompletion(
    id: 'c-${routine.id}',
    routineId: routine.id,
    petId: routine.petId,
    scheduledDate: date,
    status: status,
  ),
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

class _FakeMediaService extends MediaService {
  _FakeMediaService({required this.uploadedUrl});

  final String uploadedUrl;
  final uploadedPetIds = <String>[];

  @override
  Future<String> uploadPetPhoto({
    required String petId,
    required Uint8List bytes,
    required String filename,
  }) async {
    uploadedPetIds.add(petId);
    return uploadedUrl;
  }
}

class _FakeRecordService extends RecordService {
  _FakeRecordService({this.records = const [], this.createdRecord});

  final List<ActivityRecord> records;
  final ActivityRecord? createdRecord;
  final loadedPetIds = <String>[];
  final createdBodies = <Map<String, dynamic>>[];
  final createdMediaBodies = <Map<String, dynamic>>[];
  final uploadedFilenames = <String>[];

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

  @override
  Future<ActivityRecord> createRecord(
    String petId,
    Map<String, dynamic> body,
  ) async {
    createdBodies.add(body);
    return createdRecord ?? _record('created', petId);
  }

  @override
  Future<ActivityRecord> createRecordWithMediaBytes({
    required String petId,
    required Map<String, dynamic> body,
    required List<RecordMediaUpload> files,
  }) async {
    createdMediaBodies.add(body);
    uploadedFilenames.addAll(files.map((file) => file.filename));
    return createdRecord ?? _record('created-media', petId);
  }
}

class _FakeRoutineService extends RoutineService {
  _FakeRoutineService({this.routines = const [], this.todayItems = const []});

  final List<Routine> routines;
  final List<TodayRoutineItem> todayItems;
  final patchRequests =
      <
        (String petId, String routineId, String date, CompletionStatus status)
      >[];

  @override
  Future<List<Routine>> getRoutines(String petId) async => routines;

  @override
  Future<TodayRoutineData> getTodayRoutines(String petId) async =>
      TodayRoutineData(
        items: todayItems,
        summary: TodayRoutineSummary(
          total: todayItems.length,
          done: todayItems
              .where(
                (item) => item.completion.status == CompletionStatus.completed,
              )
              .length,
          rate: 0,
        ),
      );

  @override
  Future<RoutineCompletion> patchCompletion({
    required String petId,
    required String routineId,
    required String date,
    required CompletionStatus status,
  }) async {
    patchRequests.add((petId, routineId, date, status));
    return RoutineCompletion(
      id: 'patched-$routineId',
      routineId: routineId,
      petId: petId,
      scheduledDate: date,
      status: status,
    );
  }
}
