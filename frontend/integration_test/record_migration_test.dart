// Disposable local DB and isolated Android package only; use --no-uninstall.
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/record_service.dart';
import 'package:frontend/services/routine_service.dart';

const _types = [
  'meal',
  'water',
  'medicine',
  'poop',
  'walk',
  'weight',
  'vet',
  'diary',
  'etc',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('JPA records all types, media, routine link and persistence', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    expect(
      (await getExternalStorageDirectory())!.path,
      contains('com.formypet.frontend.mediatest/'),
    );
    initApiClient('http://127.0.0.1:18083');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_RECORD');
    final service = RecordService();
    if (!existing) {
      final random = Random.secure();
      await AuthService().register(
        email:
            'record-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
        password: List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join(),
        nickname: 'JPA 기록 검증',
      );
      await PetService().createPet({'name': '기록 검증', 'species': 'dog'});
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FormypetApp(),
      ),
    );
    await _until(
      tester,
      () =>
          !container.read(authProvider).isLoading &&
          !container.read(petProvider).isLoading,
    );
    expect(container.read(authProvider).isAuthenticated, isTrue);
    final pet = (await PetService().getPets()).single;
    final router = container.read(routerProvider);
    if (!existing) {
      for (final type in _types) {
        router.go('/records/$type/new');
        final save = type == 'meal'
            ? 'meal-save-button'
            : 'category-save-button';
        await _until(
          tester,
          () => find
              .byKey(
                Key(type == 'meal' ? 'meal-date-label' : 'category-date-label'),
              )
              .evaluate()
              .isNotEmpty,
        );
        await _fill(tester, type, false);
        await _tap(tester, find.byKey(Key(save)));
        await _until(
          tester,
          () =>
              container.read(petProvider).records.any((r) => r.typeId == type),
        );
        final created = (await service.getRecords(pet.id, typeId: type)).single;
        _check(created, false);
        router.go('/records/${created.id}');
        await _until(
          tester,
          () => find
              .byKey(const Key('record-detail-date-label'))
              .evaluate()
              .isNotEmpty,
        );
        expect(find.text(created.date), findsOneWidget);
        await _tap(tester, find.byKey(const Key('record-detail-edit-button')));
        await _until(
          tester,
          () => find
              .byKey(
                Key(type == 'meal' ? 'meal-date-label' : 'category-date-label'),
              )
              .evaluate()
              .isNotEmpty,
        );
        await _fill(tester, type, true);
        await _tap(tester, find.byKey(const Key('record-edit-save-button')));
        await _until(
          tester,
          () => find
              .byKey(const Key('record-edit-save-button'))
              .evaluate()
              .isEmpty,
        );
        _check(await service.getRecord(pet.id, created.id), true);
        debugPrint('RECORD_TYPE_UI_VERIFIED $type');
      }
      final date = (await service.getRecords(pet.id)).first.date;
      // These cross-domain operations have no dedicated control in the current UI.
      final routine = await RoutineService().createRoutine(pet.id, {
        'label': '기록 연결 검증',
        'typeId': 'water',
        'repeatType': 'daily',
        'startDate': date,
        'times': ['09:05'],
        'notificationEnabled': false,
      });
      final linked = await service.createRecord(pet.id, {
        'typeId': 'water',
        'date': date,
        'time': '09:05',
        'routineId': int.parse(routine.id),
        'detail': {'amount': 50},
      });
      expect(linked.routineId, routine.id);
      await dio.patch(
        '/api/v1/pets/${pet.id}/routines/${routine.id}/completions/$date',
        data: {'status': 'COMPLETED'},
      );
      await service.deleteRecord(pet.id, linked.id);
      final today =
          unwrap(
                await dio.get(
                  '/api/v1/pets/${pet.id}/routines/today',
                  queryParameters: {'date': date},
                ),
              )
              as Map<String, dynamic>;
      final completion = (today['routines'] as List).single['completion'];
      expect(completion['status'], 'COMPLETED');
      // Completion record links are not exposed by this API. The backend
      // integration test seeds the FK and verifies ON DELETE SET NULL.

      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 16, 16),
        Paint()..color = Colors.orange,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      final photo = await service.createRecordWithMediaBytes(
        petId: pet.id,
        body: {
          'typeId': 'meal',
          'date': date,
          'note': 'JPA 사진',
          'detail': {
            'foodType': 'dry',
            'servedAmount': 20,
            'consumedPercent': 100,
          },
        },
        files: [RecordMediaUpload(bytes: bytes, filename: 'record.png')],
      );
      expect(photo.mediaUrls, hasLength(1));
      await container.read(petProvider.notifier).retryRecordRefresh();
      await _photo(tester, container, photo);

      // Delete each type through its edit screen, preserving one edited fixture.
      for (final type in _types) {
        final temporary = await service.createRecord(pet.id, {
          'typeId': type,
          'date': date,
          'note': '삭제 검증',
        });
        await container.read(petProvider.notifier).retryRecordRefresh();
        router.go('/records/${temporary.id}/edit');
        await _until(
          tester,
          () => find
              .byKey(
                Key(type == 'meal' ? 'meal-date-label' : 'category-date-label'),
              )
              .evaluate()
              .isNotEmpty,
        );
        await _tap(tester, find.byKey(const Key('record-edit-delete-button')));
        await _tap(
          tester,
          find.byKey(const Key('app-confirmation-sheet-cancel')),
        );
        expect(
          (await service.getRecord(pet.id, temporary.id)).id,
          temporary.id,
        );
        await _tap(tester, find.byKey(const Key('record-edit-delete-button')));
        await _tap(
          tester,
          find.byKey(const Key('record-delete-confirm-button')),
        );
        await _until(
          tester,
          () => !container
              .read(petProvider)
              .records
              .any((r) => r.id == temporary.id),
        );
        expect(
          (await service.getRecords(pet.id)).any((r) => r.id == temporary.id),
          isFalse,
        );
      }
      // Also exercise deletion of an attachment; retain the first for restart rendering.
      final removable = await service.createRecordWithMediaBytes(
        petId: pet.id,
        body: {'typeId': 'meal', 'date': date},
        files: [RecordMediaUpload(bytes: bytes, filename: 'delete.png')],
      );
      await service.deleteRecord(pet.id, removable.id);
      expect(
        (await service.getRecords(pet.id)).any((r) => r.id == removable.id),
        isFalse,
      );
    }
    final saved = await service.getRecords(pet.id);
    expect(saved, hasLength(10));
    for (final type in _types) {
      final record = saved.singleWhere(
        (r) => r.typeId == type && r.note != 'JPA 사진',
      );
      _check(record, true);
      final filtered = await service.getRecords(
        pet.id,
        date: record.date,
        typeId: type,
      );
      expect(
        filtered.every((r) => r.typeId == type && r.date == record.date),
        isTrue,
      );
      expect(filtered.map((r) => r.id), contains(record.id));
    }
    expect(await service.getRecords(pet.id, date: '2000-01-01'), isEmpty);
    expect(await service.getRecords(pet.id, limit: 0), isEmpty);
    expect(
      (await service.getRecords(pet.id, limit: 2)).map((r) => r.id),
      saved.take(2).map((r) => r.id),
    );
    await container.read(petProvider.notifier).retryRecordRefresh();
    router.go('/records');
    await _until(
      tester,
      () => find.byKey(const Key('records-calendar')).evaluate().isNotEmpty,
    );
    expect(find.byKey(const Key('records-selected-date')), findsOneWidget);
    await _photo(
      tester,
      container,
      saved.singleWhere((r) => r.note == 'JPA 사진'),
    );
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'RECORD_RESTART_VERIFIED' : 'RECORD_UI_VERIFIED');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Future<void> _photo(
  WidgetTester tester,
  ProviderContainer container,
  ActivityRecord record,
) async {
  container.read(routerProvider).go('/records/${record.id}');
  await _until(
    tester,
    () => find
        .byKey(const Key('record-detail-photo-section'))
        .evaluate()
        .isNotEmpty,
  );
  await Scrollable.ensureVisible(
    tester.element(find.byKey(const Key('record-detail-photo-section'))),
    alignment: 0.5,
  );
  await _until(
    tester,
    () => tester
        .widgetList<RawImage>(
          find.descendant(
            of: find.byKey(const Key('record-detail-photo-section')),
            matching: find.byType(RawImage),
          ),
        )
        .any((image) => image.image != null),
  );
}

Future<void> _fill(WidgetTester tester, String type, bool edit) async {
  final suffix = edit ? '수정' : '등록';
  switch (type) {
    case 'meal':
      await _tap(
        tester,
        find.byKey(Key('meal-food-type-${edit ? 'wet' : 'dry'}')),
      );
      await _number(tester, 'meal-served-amount-field', edit ? '80' : '50');
      await _tap(tester, find.byKey(const Key('meal-consumed-100')));
      await _text(tester, 'meal-note-field', 'JPA $suffix');
    case 'water':
      await _number(
        tester,
        'category-water-amount-field',
        edit ? '250' : '120',
      );
    case 'walk':
      await _number(tester, 'category-distance-field', edit ? '2.5' : '1.5');
      await _text(tester, 'category-note-field', 'JPA $suffix');
    case 'weight':
      await _number(tester, 'category-weight-field', edit ? '5.5' : '4.5');
    case 'medicine':
      await _text(tester, 'category-medicine-name-field', '영양제 $suffix');
      await _text(tester, 'category-dosage-field', edit ? '2정' : '1정');
    case 'vet':
      await _text(tester, 'category-vet-clinic-field', '동물병원 $suffix');
      await _text(tester, 'category-vet-reason-field', '검진');
      await _text(tester, 'category-vet-treatment-field', '진료 $suffix');
    case 'poop':
      await _tap(tester, find.byKey(const Key('category-poop-shape-normal')));
      await _tap(tester, find.byKey(const Key('category-poop-color-brown')));
      await _text(tester, 'category-note-field', 'JPA $suffix');
    case 'diary':
    case 'etc':
      await _text(tester, 'category-$type-note-field', 'JPA $suffix');
  }
}

void _check(ActivityRecord record, bool edit) {
  final d = record.detail;
  switch (record.typeId) {
    case 'meal':
      expect(d['foodType'], edit ? 'wet' : 'dry');
      expect(d['servedAmount'], edit ? 80 : 50);
    case 'water':
      expect(d['amount'], edit ? 250 : 120);
    case 'walk':
      expect(d['distance'], edit ? 2.5 : 1.5);
    case 'weight':
      expect(d['weight'], edit ? 5.5 : 4.5);
    case 'medicine':
      expect(d['dosage'], edit ? '2정' : '1정');
    case 'vet':
      expect(d['vetTreatment'], edit ? '진료 수정' : '진료 등록');
    case 'poop':
      expect(d['poopShape'], 'normal');
      expect(record.note, edit ? 'JPA 수정' : 'JPA 등록');
    case 'diary':
    case 'etc':
      expect(record.note, edit ? 'JPA 수정' : 'JPA 등록');
      expect(d, isEmpty);
  }
}

Future<void> _number(WidgetTester tester, String key, String value) async {
  await _tap(tester, find.byKey(Key(key)));
  for (var i = 0; i < 8; i++) {
    await _tap(tester, find.byKey(const Key('record-number-key-backspace')));
  }
  for (final digit in value.split('')) {
    await _tap(
      tester,
      find.byKey(Key('record-number-key-${digit == '.' ? 'dot' : digit}')),
    );
  }
  await _tap(tester, find.byKey(const Key('record-picker-done')));
}

Future<void> _text(WidgetTester tester, String key, String value) async {
  final target = find.byKey(Key(key));
  await _reveal(tester, target);
  await tester.pumpAndSettle();
  await tester.enterText(target, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await _reveal(tester, target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final vertical = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    // The first vertical Scrollable is the page; later ones can be offscreen
    // multiline text editors with zero scroll extent.
    await tester.scrollUntilVisible(target, 180, scrollable: vertical.first);
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Record UI did not become ready');
}
