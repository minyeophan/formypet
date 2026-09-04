import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/care_schedule.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/services/care_schedule_service.dart';
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

  test('refreshPets preserves active pet and its loaded data', () async {
    final first = _pet('1');
    final second = _pet('2');
    final petService = _FakePetService(pets: [first, second]);
    final notifier = PetNotifier(
      petService,
      _FakeRecordService(records: [_record('r1', first.id)]),
      _FakeRoutineService(),
    );
    await notifier.loadForAuthenticatedUser();
    final records = notifier.state.records;

    petService.pets = [first, second];
    await notifier.refreshPets();

    expect(notifier.state.activePetId, first.id);
    expect(notifier.state.records, same(records));
  });

  test('refreshPets clears pet data when active pet was deleted', () async {
    final first = _pet('1');
    final second = _pet('2');
    final petService = _FakePetService(pets: [first]);
    final recordService = _FakeRecordService(
      records: [_record('r1', first.id)],
    );
    final notifier = PetNotifier(
      petService,
      recordService,
      _FakeRoutineService(),
    );
    await notifier.loadForAuthenticatedUser();

    petService.pets = [second];
    recordService.failPetIds.add(second.id);
    await expectLater(notifier.refreshPets(), throwsException);

    expect(notifier.state.activePetId, second.id);
    expect(notifier.state.records, isEmpty);
    expect(notifier.state.routines, isEmpty);
    expect(notifier.state.todayRoutineItems, isEmpty);
  });

  test('late pet data response cannot overwrite the active pet', () async {
    final first = _pet('1');
    final second = _pet('2');
    final records = _DelayedRecordService();
    final notifier = PetNotifier(
      _FakePetService(pets: [first, second]),
      records,
      _FakeRoutineService(),
    );
    final load = notifier.loadForAuthenticatedUser();
    await Future<void>.delayed(Duration.zero);
    records.complete(first.id, [_record('r1', first.id)]);
    await load;

    final firstRequest = notifier.setActivePet(first.id);
    final secondRequest = notifier.setActivePet(second.id);
    records.complete(second.id, [_record('r2', second.id)]);
    await secondRequest;
    records.complete(first.id, [_record('late', first.id)]);
    await firstRequest;

    expect(notifier.state.activePetId, second.id);
    expect(notifier.state.records.single.petId, second.id);
  });

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
    expect(notifier.state.todaySummary?.done, 1);
    expect(notifier.state.todaySummary?.rate, 100.0);
  });

  test('addRoutine appends routine and refreshes today routines', () async {
    final pet = _pet('1');
    final original = _routine('rt1', pet.id);
    final created = _routine('rt2', pet.id);
    final routineService = _FakeRoutineService(
      routines: [original],
      todayItems: [
        _todayRoutineItem(
          routine: original,
          date: '2026-06-01',
          status: CompletionStatus.pending,
        ),
      ],
      createdRoutine: created,
    );
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      _FakeRecordService(),
      routineService,
    );
    await notifier.loadForAuthenticatedUser();
    routineService.todayItems = [
      _todayRoutineItem(
        routine: created,
        date: '2026-06-01',
        status: CompletionStatus.completed,
      ),
    ];

    await notifier.addRoutine({'label': 'Routine rt2'});

    expect(notifier.state.routines, [original, created]);
    expect(notifier.state.todayRoutineItems.single.routine, created);
    expect(notifier.state.routineCompletions, {
      'rt2:2026-06-01': CompletionStatus.completed,
    });
  });

  test('addRoutine keeps local success when today refresh fails', () async {
    final pet = _pet('1');
    final created = _routine('rt2', pet.id);
    final routineService = _FakeRoutineService(createdRoutine: created);
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      _FakeRecordService(),
      routineService,
    );
    await notifier.loadForAuthenticatedUser();
    routineService.failTodayRefresh = true;

    await notifier.addRoutine({'label': 'Routine rt2'});

    expect(notifier.state.routines, [created]);
  });

  test('addCareSchedule appends server-created active pet schedule', () async {
    final pet = _pet('1');
    final scheduleService = _FakeCareScheduleService(
      createdSchedule: _schedule('server-s1', pet.id),
    );
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      _FakeRecordService(),
      _FakeRoutineService(),
      null,
      scheduleService,
    );
    await notifier.loadForAuthenticatedUser();

    await notifier.addCareSchedule(_schedule('s1', pet.id));

    expect(scheduleService.createdRequests.single.id, 's1');
    expect(notifier.state.schedules.map((schedule) => schedule.id), [
      'server-s1',
    ]);
  });

  test(
    'updateCareSchedule replaces matching active pet schedule from server',
    () async {
      final pet = _pet('1');
      final scheduleService = _FakeCareScheduleService(
        schedules: [_schedule('s1', pet.id)],
      );
      final notifier = PetNotifier(
        _FakePetService(pets: [pet]),
        _FakeRecordService(),
        _FakeRoutineService(),
        null,
        scheduleService,
      );
      await notifier.loadForAuthenticatedUser();

      final updated = CareSchedule(
        id: 's1',
        petId: pet.id,
        categoryId: 'hospital',
        title: 'Updated schedule',
        startDate: '2026-06-20',
        startTime: '14:00',
        endDate: '2026-06-20',
        endTime: '14:30',
        allDay: false,
        place: 'Clinic',
        memo: 'Bring note',
        reminder: '2 hours before',
        createdAt: '2026-06-01T00:00:00.000',
      );
      await notifier.updateCareSchedule(updated);

      expect(notifier.state.schedules, hasLength(1));
      expect(notifier.state.schedules.single.title, 'Updated schedule');
      expect(scheduleService.updatedRequests.single.$1, 's1');
      expect(scheduleService.updatedRequests.single.$2.categoryId, 'hospital');
      expect(scheduleService.updatedRequests.single.$2.startDate, '2026-06-20');
      expect(scheduleService.updatedRequests.single.$2.startTime, '14:00');
      expect(scheduleService.updatedRequests.single.$2.place, 'Clinic');
      expect(scheduleService.updatedRequests.single.$2.memo, 'Bring note');
      expect(
        scheduleService.updatedRequests.single.$2.reminder,
        '2 hours before',
      );
    },
  );

  test(
    'updateCareSchedule rejects missing id or inactive pet schedules',
    () async {
      final pet = _pet('1');
      final scheduleService = _FakeCareScheduleService(
        schedules: [_schedule('s1', pet.id)],
      );
      final notifier = PetNotifier(
        _FakePetService(pets: [pet]),
        _FakeRecordService(),
        _FakeRoutineService(),
        null,
        scheduleService,
      );
      await notifier.loadForAuthenticatedUser();

      expect(
        () => notifier.updateCareSchedule(_schedule('missing', pet.id)),
        throwsA(isA<StateError>()),
      );
      expect(
        () => notifier.updateCareSchedule(_schedule('s1', 'other-pet')),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'updateCareSchedule clears optional and all day time fields from server response',
    () async {
      final pet = _pet('1');
      final scheduleService = _FakeCareScheduleService(
        schedules: [_schedule('s1', pet.id)],
      );
      final notifier = PetNotifier(
        _FakePetService(pets: [pet]),
        _FakeRecordService(),
        _FakeRoutineService(),
        null,
        scheduleService,
      );
      await notifier.loadForAuthenticatedUser();

      await notifier.updateCareSchedule(
        CareSchedule(
          id: 's1',
          petId: pet.id,
          categoryId: 'grooming',
          title: 'All day bath',
          startDate: '2026-06-17',
          endDate: '2026-06-17',
          allDay: true,
          reminder: 'none',
          createdAt: '2026-06-01T00:00:00.000',
        ),
      );

      final schedule = notifier.state.schedules.single;
      expect(schedule.place, isNull);
      expect(schedule.memo, isNull);
      expect(schedule.startTime, isNull);
      expect(schedule.endTime, isNull);
    },
  );

  test(
    'deleteCareSchedule removes active pet schedule through server',
    () async {
      final pet = _pet('1');
      final scheduleService = _FakeCareScheduleService(
        schedules: [_schedule('s1', pet.id), _schedule('s2', pet.id)],
      );
      final notifier = PetNotifier(
        _FakePetService(pets: [pet]),
        _FakeRecordService(),
        _FakeRoutineService(),
        null,
        scheduleService,
      );
      await notifier.loadForAuthenticatedUser();

      await notifier.deleteCareSchedule('s1');

      expect(notifier.state.schedules.map((schedule) => schedule.id), ['s2']);
      expect(scheduleService.deletedRequests, [('1', 's1')]);
    },
  );

  test('deleteCareSchedule removes last schedule from state', () async {
    final pet = _pet('1');
    final scheduleService = _FakeCareScheduleService(
      schedules: [_schedule('s1', pet.id)],
    );
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      _FakeRecordService(),
      _FakeRoutineService(),
      null,
      scheduleService,
    );
    await notifier.loadForAuthenticatedUser();

    await notifier.deleteCareSchedule('s1');

    expect(notifier.state.schedules, isEmpty);
    expect(scheduleService.deletedRequests, [('1', 's1')]);
  });

  test(
    'deleteCareSchedule rejects no active pet missing id and inactive pet',
    () async {
      final pet = _pet('1');
      final scheduleService = _FakeCareScheduleService(
        schedules: [_schedule('s1', pet.id)],
      );
      final notifier = PetNotifier(
        _FakePetService(pets: [pet]),
        _FakeRecordService(),
        _FakeRoutineService(),
        null,
        scheduleService,
      );
      await notifier.loadForAuthenticatedUser();

      expect(
        () => notifier.deleteCareSchedule('missing'),
        throwsA(isA<StateError>()),
      );
      final inactiveNotifier = PetNotifier.test(
        PetState(
          isLoading: false,
          hasOnboarded: true,
          pets: [_pet('1'), _pet('2')],
          activePetId: '1',
          records: const [],
          routines: const [],
          schedules: [_schedule('inactive-schedule', '2')],
          todayRoutineItems: const [],
          routineCompletions: const {},
          quickTypeIds: const ['meal', 'water'],
        ),
      );
      expect(
        () => inactiveNotifier.deleteCareSchedule('inactive-schedule'),
        throwsA(isA<StateError>()),
      );

      final noActiveNotifier = PetNotifier.test(
        const PetState(
          isLoading: false,
          hasOnboarded: false,
          pets: [],
          activePetId: null,
          records: [],
          routines: [],
          schedules: [],
          todayRoutineItems: [],
          routineCompletions: {},
          quickTypeIds: ['meal', 'water'],
        ),
      );
      expect(
        () => noActiveNotifier.deleteCareSchedule('s1'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('loadForAuthenticatedUser loads server care schedules', () async {
    final pet = _pet('1');
    final scheduleService = _FakeCareScheduleService(
      schedules: [_schedule('s1', '1')],
    );
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      _FakeRecordService(),
      _FakeRoutineService(),
      null,
      scheduleService,
    );

    await notifier.loadForAuthenticatedUser();

    expect(notifier.state.schedules.single.id, 's1');
  });

  test(
    'deleteRoutine removes all completion keys for deleted routine',
    () async {
      final pet = _pet('1');
      final routine = _routine('rt1', pet.id);
      final routineService = _FakeRoutineService(
        routines: [routine],
        todayItems: [
          _todayRoutineItem(
            routine: routine,
            date: '2026-06-01',
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
      await notifier.toggleRoutineCompletion('rt1', '2026-06-20');
      routineService.todayItems = const [];

      await notifier.deleteRoutine('rt1');

      expect(notifier.state.routines, isEmpty);
      expect(notifier.state.routineCompletions, isEmpty);
      expect(routineService.deletedRoutineIds, [('1', 'rt1')]);
    },
  );

  test('clearForSignedOutUser clears account-scoped pet data', () async {
    final pet = _pet('1');
    final scheduleService = _FakeCareScheduleService();
    final notifier = PetNotifier(
      _FakePetService(pets: [pet]),
      _FakeRecordService(records: [_record('r1', pet.id)]),
      _FakeRoutineService(routines: [_routine('rt1', pet.id)]),
      null,
      scheduleService,
    );
    await notifier.loadForAuthenticatedUser();
    await notifier.addCareSchedule(_schedule('s1', pet.id));
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
    expect(notifier.state.schedules, isEmpty);
    expect(notifier.state.quickTypeIds, const ['meal', 'water']);
  });

  test(
    'stored quick types remove only removed values and persist migration',
    () async {
      SharedPreferences.setMockInitialValues({
        'quickTypeIds': ['meal', 'bath', 'unknown', 'meal', 'groom'],
      });
      final notifier = PetNotifier(
        _FakePetService(pets: const []),
        _FakeRecordService(),
        _FakeRoutineService(),
      );

      await notifier.loadForAuthenticatedUser();

      const expected = ['meal', 'unknown', 'meal'];
      expect(notifier.state.quickTypeIds, expected);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('quickTypeIds'), expected);
    },
  );

  test(
    'test quick type loader removes only removed values before state update',
    () async {
      final notifier = PetNotifier.testWithServices(
        PetState(
          isLoading: true,
          hasOnboarded: false,
          pets: const [],
          records: const [],
          routines: const [],
          schedules: const [],
          todayRoutineItems: const [],
          routineCompletions: const {},
          quickTypeIds: const [],
        ),
        quickTypeIdsLoader: () async => const [
          'bath',
          'unknown',
          'bath',
          'groom',
        ],
      );

      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.quickTypeIds, const ['unknown']);
    },
  );

  test('setQuickTypeIds removes only removed values before saving', () async {
    final notifier = PetNotifier.test(
      PetState(
        isLoading: false,
        hasOnboarded: false,
        pets: const [],
        records: const [],
        routines: const [],
        schedules: const [],
        todayRoutineItems: const [],
        routineCompletions: const {},
        quickTypeIds: const [],
      ),
    );

    await notifier.setQuickTypeIds(const [
      'meal',
      'unknown',
      'meal',
      'bath',
      'groom',
    ]);

    const expected = ['meal', 'unknown', 'meal'];
    expect(notifier.state.quickTypeIds, expected);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('quickTypeIds'), expected);
  });

  test(
    'clearForSignedOutUser clears immediately while quick types are loading',
    () async {
      final loader = Completer<List<String>>();
      final notifier = PetNotifier.testWithServices(
        PetState(
          isLoading: true,
          hasOnboarded: true,
          pets: [_pet('1')],
          activePetId: '1',
          records: [_record('r1', '1')],
          routines: [_routine('rt1', '1')],
          schedules: [_schedule('s1', '1')],
          todayRoutineItems: [
            _todayRoutineItem(
              routine: _routine('rt1', '1'),
              date: '2026-06-30',
              status: CompletionStatus.completed,
            ),
          ],
          routineCompletions: const {
            'rt1:2026-06-30': CompletionStatus.completed,
          },
          todaySummary: const TodayRoutineSummary(total: 1, done: 1, rate: 1),
          quickTypeIds: const ['meal', 'water'],
        ),
        quickTypeIdsLoader: () => loader.future,
      );

      final clearFuture = notifier.clearForSignedOutUser();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.hasOnboarded, isFalse);
      expect(notifier.state.pets, isEmpty);
      expect(notifier.state.activePetId, isNull);
      expect(notifier.state.records, isEmpty);
      expect(notifier.state.routines, isEmpty);
      expect(notifier.state.schedules, isEmpty);
      expect(notifier.state.todayRoutineItems, isEmpty);
      expect(notifier.state.routineCompletions, isEmpty);
      expect(notifier.state.todaySummary, isNull);
      expect(notifier.state.quickTypeIds, const ['meal', 'water']);

      loader.complete(const ['walk', 'vet']);
      await clearFuture;
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.quickTypeIds, const ['walk', 'vet']);
      expect(notifier.state.pets, isEmpty);
      expect(notifier.state.activePetId, isNull);
      expect(notifier.state.records, isEmpty);
      expect(notifier.state.routines, isEmpty);
      expect(notifier.state.schedules, isEmpty);
    },
  );

  test(
    'failed quick type loading does not block signed-out state cleanup',
    () async {
      final loader = Completer<List<String>>();
      final notifier = PetNotifier.testWithServices(
        PetState(
          isLoading: true,
          hasOnboarded: true,
          pets: [_pet('1')],
          activePetId: '1',
          records: [_record('r1', '1')],
          routines: const [],
          schedules: const [],
          todayRoutineItems: const [],
          routineCompletions: const {},
          quickTypeIds: const ['meal', 'water'],
        ),
        quickTypeIdsLoader: () => loader.future,
      );

      final clearFuture = notifier.clearForSignedOutUser();
      loader.completeError(Exception('preferences unavailable'));
      await clearFuture;
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.hasOnboarded, isFalse);
      expect(notifier.state.pets, isEmpty);
      expect(notifier.state.activePetId, isNull);
      expect(notifier.state.quickTypeIds, const ['meal', 'water']);
    },
  );

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

  test(
    'failed photo keeps created pet without completing onboarding',
    () async {
      final notifier = PetNotifier(
        _FakePetService(pets: [], createdPet: _pet('2')),
        _FakeRecordService(),
        _FakeRoutineService(),
        _FailingPetPhotoService(),
      );
      await expectLater(
        notifier.addPet(
          {'name': 'Bori'},
          photo: PetPhotoUpload(
            bytes: Uint8List.fromList([1]),
            filename: 'pet.png',
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('사진'))),
      );
      expect(notifier.state.pets.single.id, '2');
      expect(notifier.state.hasOnboarded, isFalse);
    },
  );

  test(
    'retrying saved pet photo completes onboarding without another create',
    () async {
      final service = _FakePetService(pets: [], createdPet: _pet('2'));
      final media = _FailingPetPhotoService();
      final notifier = PetNotifier(
        service,
        _FakeRecordService(),
        _FakeRoutineService(),
        media,
      );
      final photo = PetPhotoUpload(
        bytes: Uint8List.fromList([1]),
        filename: 'pet.png',
      );
      await expectLater(
        notifier.addPet({'name': 'Bori'}, photo: photo),
        throwsA(isA<PetPhotoSaveException>()),
      );
      media.fail = false;
      await notifier.updatePet('2', {
        'name': 'Bori',
        'species': 'dog',
      }, photo: photo);
      expect(service.createCount, 1);
      expect(service.updatedPetIds, ['2']);
      expect(notifier.state.hasOnboarded, isTrue);
      expect(notifier.state.pets.single.profileImageUrl, '/api/v1/media/retry');
    },
  );

  test(
    'new pet refresh failure does not turn saved creation into a failed save',
    () async {
      final records = _FakeRecordService()..failPetIds.add('2');
      final notifier = PetNotifier(
        _FakePetService(pets: [], createdPet: _pet('2')),
        records,
        _FakeRoutineService(),
      );
      await notifier.addPet({'name': 'Bori'});
      expect(notifier.state.pets.single.id, '2');
      expect(notifier.state.hasOnboarded, isTrue);
    },
  );

  test('deletePet clears onboarding after deleting the last pet', () async {
    final pet = _pet('1');
    final petService = _FakePetService(pets: [pet]);
    final scheduleService = _FakeCareScheduleService();
    final notifier = PetNotifier(
      petService,
      _FakeRecordService(),
      _FakeRoutineService(),
      null,
      scheduleService,
    );
    await notifier.loadForAuthenticatedUser();
    await notifier.addCareSchedule(_schedule('s1', pet.id));

    await notifier.deletePet(pet.id);

    expect(petService.deletedPetIds, ['1']);
    expect(notifier.state.hasOnboarded, isFalse);
    expect(notifier.state.pets, isEmpty);
    expect(notifier.state.activePetId, isNull);
  });

  test('deletePet activates and reloads the next pet', () async {
    final firstPet = _pet('1');
    final secondPet = _pet('2');
    final recordService = _FakeRecordService();
    final notifier = PetNotifier(
      _FakePetService(pets: [firstPet, secondPet]),
      recordService,
      _FakeRoutineService(),
    );
    await notifier.loadForAuthenticatedUser();

    await notifier.deletePet(firstPet.id);

    expect(notifier.state.activePetId, '2');
    expect(recordService.loadedPetIds, ['1', '2']);
  });

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

CareSchedule _schedule(String id, String petId) => CareSchedule(
  id: id,
  petId: petId,
  categoryId: 'grooming',
  title: '목욕 예약',
  startDate: '2026-06-17',
  startTime: '10:30',
  endDate: '2026-06-17',
  endTime: '11:00',
  allDay: false,
  place: '동네 미용실',
  memo: null,
  reminder: '하루 전',
  createdAt: '2026-06-01T00:00:00.000',
);

Routine _routine(String id, String petId) => Routine(
  id: id,
  petId: petId,
  label: 'Routine $id',
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

  List<Pet> pets;
  final Pet? createdPet;
  final deletedPetIds = <String>[];
  int createCount = 0;
  final updatedPetIds = <String>[];

  @override
  Future<List<Pet>> getPets() async => pets;

  @override
  Future<Pet> createPet(Map<String, dynamic> body) async {
    createCount++;
    return createdPet ?? _pet('created');
  }

  @override
  Future<Pet> updatePet(String petId, Map<String, dynamic> body) async {
    updatedPetIds.add(petId);
    return Pet.fromJson({'id': petId, ...body});
  }

  @override
  Future<void> deletePet(String petId) async {
    deletedPetIds.add(petId);
  }
}

class _FailingPetPhotoService extends MediaService {
  bool fail = true;
  @override
  Future<String> uploadPetPhoto({
    required String petId,
    required Uint8List bytes,
    required String filename,
  }) async {
    if (fail) throw Exception('upload unavailable');
    return '/api/v1/media/retry';
  }
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
  final failPetIds = <String>{};
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
    if (failPetIds.contains(petId)) {
      throw Exception('record load failed');
    }
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

class _DelayedRecordService extends RecordService {
  final _requests = <String, List<Completer<List<ActivityRecord>>>>{};

  @override
  Future<List<ActivityRecord>> getRecords(
    String petId, {
    String? date,
    String? typeId,
    int? limit,
  }) {
    final completer = Completer<List<ActivityRecord>>();
    _requests.putIfAbsent(petId, () => []).add(completer);
    return completer.future;
  }

  void complete(String petId, List<ActivityRecord> records) {
    _requests[petId]!.removeAt(0).complete(records);
  }
}

class _FakeCareScheduleService extends CareScheduleService {
  _FakeCareScheduleService({this.schedules = const [], this.createdSchedule});

  final List<CareSchedule> schedules;
  final CareSchedule? createdSchedule;
  final createdRequests = <CareSchedule>[];
  final updatedRequests = <(String scheduleId, CareSchedule schedule)>[];
  final deletedRequests = <(String petId, String scheduleId)>[];

  @override
  Future<List<CareSchedule>> getSchedules(String petId) async => schedules;

  @override
  Future<CareSchedule> createSchedule(
    String petId,
    CareSchedule schedule,
  ) async {
    createdRequests.add(schedule);
    return createdSchedule ?? schedule;
  }

  @override
  Future<CareSchedule> updateSchedule(
    String petId,
    String scheduleId,
    CareSchedule schedule,
  ) async {
    updatedRequests.add((scheduleId, schedule));
    return schedule;
  }

  @override
  Future<void> deleteSchedule(String petId, String scheduleId) async {
    deletedRequests.add((petId, scheduleId));
  }
}

class _FakeRoutineService extends RoutineService {
  _FakeRoutineService({
    this.routines = const [],
    this.todayItems = const [],
    this.createdRoutine,
  });

  final List<Routine> routines;
  List<TodayRoutineItem> todayItems;
  final Routine? createdRoutine;
  bool failTodayRefresh = false;
  final deletedRoutineIds = <(String petId, String routineId)>[];
  final patchRequests =
      <
        (String petId, String routineId, String date, CompletionStatus status)
      >[];

  @override
  Future<List<Routine>> getRoutines(String petId) async => routines;

  @override
  Future<TodayRoutineData> getTodayRoutines(String petId) async =>
      failTodayRefresh
      ? throw Exception('today refresh failed')
      : TodayRoutineData(
          items: todayItems,
          summary: TodayRoutineSummary(
            total: todayItems.length,
            done: todayItems
                .where(
                  (item) =>
                      item.completion.status == CompletionStatus.completed,
                )
                .length,
            rate: 0,
          ),
        );

  @override
  Future<Routine> createRoutine(
    String petId,
    Map<String, dynamic> body,
  ) async => createdRoutine ?? _routine('created', petId);

  @override
  Future<Routine> updateRoutine(
    String petId,
    String routineId,
    Map<String, dynamic> body,
  ) async => _routine(routineId, petId);

  @override
  Future<void> deleteRoutine(String petId, String routineId) async {
    deletedRoutineIds.add((petId, routineId));
  }

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
