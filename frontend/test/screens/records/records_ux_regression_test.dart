import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/records/meal_record_screen.dart';
import 'package:frontend/screens/records/record_category_form_screen.dart';
import 'package:frontend/screens/records/record_detail_screen.dart';
import 'package:frontend/screens/records/record_edit_screen.dart';
import 'package:frontend/screens/records/records_screen.dart';
import 'package:frontend/widgets/record_inputs/record_inputs.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final isMeal in [true, false]) {
    testWidgets(
      '${isMeal ? 'meal' : 'category'} delete double callback opens one confirmation',
      (tester) async {
        final notifier = FakeRecords();
        await pump(
          tester,
          isMeal
              ? MealRecordScreen(editingRecord: meal('delete-me', 'food'))
              : const RecordCategoryFormScreen(
                  typeId: 'diary',
                  editingRecord: ActivityRecord(
                    id: 'delete-me',
                    petId: 'pet',
                    typeId: 'diary',
                    date: '2026-09-21',
                    note: 'saved',
                  ),
                ),
          notifier: notifier,
        );
        final remove = tester
            .widget<RecordEditActionBar>(find.byType(RecordEditActionBar))
            .onDelete;
        remove();
        remove();
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet, skipOffstage: false), findsOneWidget);
        expect(notifier.deleted, isEmpty);
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet, skipOffstage: false), findsNothing);
        expect(notifier.deleted, isEmpty);
        remove();
        remove();
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet, skipOffstage: false), findsOneWidget);
        expect(notifier.deleted, isEmpty);
        await tester.tap(find.byKey(const Key('record-delete-confirm-button')));
        await tester.pumpAndSettle();
        expect(notifier.deleted, ['delete-me']);
        expect(find.text('saved records'), findsOneWidget);
      },
    );
  }
  testWidgets('meal photo byte read cannot begin add after owner changes', (
    tester,
  ) async {
    final notifier = FakeRecords();
    final photo = PendingPhoto();
    await pump(
      tester,
      MealRecordScreen(pickImageForTest: () async => photo),
      notifier: notifier,
    );
    await tester.tap(find.byKey(const Key('meal-food-type-dry')));
    await tester.tap(find.byKey(const Key('meal-served-amount-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-number-key-3')));
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meal-consumed-100')));
    await tester.tap(find.byKey(const Key('meal-photo-button')));
    await tester.pumpAndSettle();
    tester
        .widget<RecordFormSubmitButton>(find.byType(RecordFormSubmitButton))
        .onPressed();
    await tester.pump();
    notifier.changeOwner();
    photo.bytes.complete(Uint8List.fromList([1, 2]));
    await tester.pumpAndSettle();
    expect(notifier.saves, 0);
    expect(find.text('saved records'), findsNothing);
  });
  for (final isMeal in [true, false]) {
    testWidgets(
      '${isMeal ? 'meal' : 'category'} time picker ignores former session result',
      (tester) async {
        final notifier = FakeRecords();
        await pump(
          tester,
          isMeal
              ? const MealRecordScreen()
              : const RecordCategoryFormScreen(typeId: 'diary'),
          notifier: notifier,
        );
        final time = find.byKey(
          Key(isMeal ? 'meal-time-button' : 'category-time-button'),
        );
        final before = tester
            .widget<Text>(
              find.descendant(of: time, matching: find.byType(Text)),
            )
            .data;
        await tester.tap(time);
        await tester.pumpAndSettle();
        notifier.changeOwner(samePet: true);
        Navigator.of(
          tester.element(find.byKey(const Key('record-picker-done'))),
        ).pop(const TimeOfDay(hour: 1, minute: 2));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.descendant(of: time, matching: find.byType(Text)),
              )
              .data,
          before,
        );
      },
    );
  }
  testWidgets(
    'editor record identity rehydrates instead of saving previous record draft',
    (tester) async {
      final notifier = FakeRecords()
        ..setRecords([meal('one', 'first'), meal('two', 'second')]);
      final selected = ValueNotifier('one');
      addTearDown(selected.dispose);
      await pump(
        tester,
        ValueListenableBuilder<String>(
          valueListenable: selected,
          builder: (_, id, _) => RecordEditScreen(recordId: id),
        ),
        notifier: notifier,
      );
      await tester.enterText(
        find.byKey(const Key('meal-product-field')),
        'old draft',
      );
      selected.value = 'two';
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('meal-product-field')))
            .controller!
            .text,
        'second',
      );
      tester
          .widget<RecordEditActionBar>(find.byType(RecordEditActionBar))
          .onSave();
      await tester.pump();
      expect(notifier.updated.single.$1, 'two');
      expect(
        (notifier.updated.single.$2['detail'] as Map)['product'],
        'second',
      );
      notifier.pending.complete();
      await tester.pumpAndSettle();
    },
  );
  for (final type in ['meal', 'diary']) {
    testWidgets(
      '$type edit retains draft across empty refresh and error but resets account identity',
      (tester) async {
        final record = type == 'meal'
            ? meal('one', 'first')
            : const ActivityRecord(
                id: 'one',
                petId: 'pet',
                typeId: 'diary',
                date: '2026-09-21',
                note: 'first',
              );
        final notifier = FakeRecords()..setRecords([record]);
        await pump(
          tester,
          const RecordEditScreen(recordId: 'one'),
          notifier: notifier,
        );
        final field = find.byKey(
          Key(
            type == 'meal' ? 'meal-product-field' : 'category-diary-note-field',
          ),
        );
        await tester.enterText(field, 'unsaved');
        notifier.clearForRefresh();
        await tester.pump();
        expect(find.text('unsaved'), findsOneWidget);
        notifier.failLoad();
        await tester.pump();
        expect(find.text('unsaved'), findsOneWidget);
        notifier.setRecords([record]);
        await tester.pump();
        expect(find.text('unsaved'), findsOneWidget);
        notifier.changeOwner(samePet: true);
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, 'first');
      },
    );
  }
  for (final edit in [false, true]) {
    testWidgets(
      'category ${edit ? 'update' : 'add'} stale success does not navigate after owner switch',
      (tester) async {
        final notifier = FakeRecords();
        await pump(
          tester,
          RecordCategoryFormScreen(
            typeId: 'diary',
            editingRecord: edit
                ? const ActivityRecord(
                    id: 'one',
                    petId: 'pet',
                    typeId: 'diary',
                    date: '2026-09-21',
                    note: 'first',
                  )
                : null,
          ),
          notifier: notifier,
        );
        await tester.enterText(
          find.byKey(const Key('category-diary-note-field')),
          'draft',
        );
        if (edit) {
          tester
              .widget<RecordEditActionBar>(find.byType(RecordEditActionBar))
              .onSave();
        } else {
          tester
              .widget<RecordFormSubmitButton>(
                find.byType(RecordFormSubmitButton),
              )
              .onPressed();
        }
        await tester.pump();
        notifier.changeOwner();
        notifier.pending.complete();
        await tester.pumpAndSettle();
        expect(find.text('saved records'), findsNothing);
        expect(find.text('draft'), findsOneWidget);
        final attempts = notifier.saves;
        if (edit) {
          tester
              .widget<RecordEditActionBar>(find.byType(RecordEditActionBar))
              .onSave();
        } else {
          tester
              .widget<RecordFormSubmitButton>(
                find.byType(RecordFormSubmitButton),
              )
              .onPressed();
        }
        await tester.pump();
        expect(notifier.saves, attempts);
      },
    );
  }
  testWidgets('meal stale update does not navigate after session switch', (
    tester,
  ) async {
    final notifier = FakeRecords();
    await pump(
      tester,
      MealRecordScreen(editingRecord: meal('one', 'first')),
      notifier: notifier,
    );
    tester
        .widget<RecordEditActionBar>(find.byType(RecordEditActionBar))
        .onSave();
    await tester.pump();
    notifier.changeOwner(samePet: true);
    notifier.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('saved records'), findsNothing);
  });
  testWidgets('meal photo picker rejects result from previous owner', (
    tester,
  ) async {
    final notifier = FakeRecords();
    final photo = Completer<XFile?>();
    await pump(
      tester,
      MealRecordScreen(pickImageForTest: () => photo.future),
      notifier: notifier,
    );
    await tester.tap(find.byKey(const Key('meal-photo-button')));
    await tester.pump();
    notifier.changeOwner();
    photo.complete(XFile('old-owner.jpg'));
    await tester.pumpAndSettle();
    expect(find.textContaining('old-owner.jpg'), findsNothing);
  });
  testWidgets('number picker rejects value after owner changes', (
    tester,
  ) async {
    final notifier = FakeRecords();
    await pump(
      tester,
      const RecordCategoryFormScreen(typeId: 'water'),
      notifier: notifier,
    );
    await tester.tap(find.byKey(const Key('category-water-amount-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-number-key-9')));
    notifier.changeOwner();
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('category-water-amount-field')),
          )
          .controller!
          .text,
      '',
    );
  });
  for (final entry in {
    'water': 'category-water-amount-field',
    'walk': 'category-distance-field',
    'weight': 'category-weight-field',
    'vet': 'category-vet-treatment-field',
    'medicine': 'category-dosage-field',
    'etc': 'category-etc-note-field',
  }.entries) {
    testWidgets(
      '${entry.key} changed input protects exit and reverting clears draft',
      (tester) async {
        await pump(tester, RecordCategoryFormScreen(typeId: entry.key));
        final field = find.byKey(Key(entry.value));
        final numeric = ['water', 'walk', 'weight'].contains(entry.key);
        if (numeric) {
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('record-number-key-1')));
          await tester.tap(find.byKey(const Key('record-picker-done')));
          await tester.pumpAndSettle();
        } else {
          await tester.enterText(field, 'draft');
        }
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('계속 입력'), findsOneWidget);
        await tester.tap(find.text('계속 입력'));
        await tester.pumpAndSettle();
        if (numeric) {
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('record-number-key-backspace')),
          );
          await tester.tap(find.byKey(const Key('record-picker-done')));
          await tester.pumpAndSettle();
        } else {
          await tester.enterText(field, '');
        }
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);
        expect(find.text('계속 입력'), findsNothing);
      },
    );
  }
  for (final screen in <Widget>[
    const MealRecordScreen(
      editingRecord: ActivityRecord(
        id: 'm',
        petId: 'pet',
        typeId: 'meal',
        date: '2026-09-21',
        time: '09:00',
        note: 'saved',
        detail: {'foodType': 'dry', 'servedAmount': 30, 'consumedPercent': 100},
      ),
    ),
    const RecordCategoryFormScreen(
      typeId: 'diary',
      editingRecord: ActivityRecord(
        id: 'd',
        petId: 'pet',
        typeId: 'diary',
        date: '2026-09-21',
        time: '09:00',
        note: 'saved',
      ),
    ),
  ]) {
    testWidgets(
      '${screen.runtimeType} hydrated unchanged edit exits without prompt',
      (tester) async {
        await pump(tester, screen);
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);
        expect(find.text('계속 입력'), findsNothing);
      },
    );
  }
  testWidgets(
    'meal pending save freezes all fields and succeeds without discard prompt',
    (tester) async {
      final notifier = FakeRecords();
      await pump(
        tester,
        const MealRecordScreen(
          editingRecord: ActivityRecord(
            id: 'm',
            petId: 'pet',
            typeId: 'meal',
            date: '2026-09-21',
            time: '09:00',
            note: 'saved',
            detail: {
              'foodType': 'dry',
              'servedAmount': 30,
              'consumedPercent': 100,
              'brand': 'brand',
            },
          ),
        ),
        notifier: notifier,
      );
      await tester.enterText(
        find.byKey(const Key('meal-note-field')),
        'changed',
      );
      final save = tester
          .widget<RecordEditActionBar>(find.byType(RecordEditActionBar))
          .onSave;
      save();
      save();
      await tester.pump();
      expect(notifier.saves, 1);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
      }
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('changed'), findsOneWidget);
      notifier.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('saved records'), findsOneWidget);
      expect(find.text('계속 입력'), findsNothing);
    },
  );
  testWidgets('poop selection alone protects exit', (tester) async {
    await pump(tester, const RecordCategoryFormScreen(typeId: 'poop'));
    await tester.tap(find.byKey(const Key('category-poop-color-brown')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('계속 입력'), findsOneWidget);
  });
  for (final width in [320.0, 375.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('meal labels fit at $width scale $scale', (tester) async {
        await pump(
          tester,
          const MealRecordScreen(),
          width: width,
          scale: scale,
        );
        for (final key in [
          'meal-date-label',
          'meal-time-button',
          'meal-food-type-freezeDried',
          'meal-consumed-100',
        ]) {
          final target = find.byKey(Key(key));
          await tester.ensureVisible(target);
          await tester.pump();
          for (final rich
              in find
                  .descendant(of: target, matching: find.byType(RichText))
                  .evaluate()) {
            final paragraph = rich.renderObject! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse, reason: key);
            expect(
              tester
                  .getRect(target)
                  .contains(
                    paragraph.localToGlobal(
                      Offset(0, paragraph.size.height - 1),
                    ),
                  ),
              isTrue,
              reason: key,
            );
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  for (final screen in <Widget>[
    const RecordDetailScreen(recordId: 'missing'),
    const RecordEditScreen(recordId: 'missing'),
    const GrowthRecordsScreen(),
  ]) {
    testWidgets('${screen.runtimeType} distinguishes loading error and empty', (
      tester,
    ) async {
      final notifier = FakeRecords(loading: true);
      await pump(tester, screen, notifier: notifier);
      expect(find.text('기록을 찾을 수 없어요'), findsNothing);
      expect(find.text('체중 기록이 없어요'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      notifier.failLoad();
      await tester.pump();
      expect(find.text('기록을 찾을 수 없어요'), findsNothing);
      expect(find.text('체중 기록이 없어요'), findsNothing);
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(find.text('다시 시도'), findsNothing);
      expect(
        find.text(
          screen is GrowthRecordsScreen ? '체중 기록이 없어요' : '기록을 찾을 수 없어요',
        ),
        findsOneWidget,
      );
    });
  }
  for (final screen in <Widget>[
    const MealRecordScreen(),
    const RecordCategoryFormScreen(typeId: 'diary'),
  ]) {
    testWidgets('${screen.runtimeType} protects typed draft on back', (
      tester,
    ) async {
      await pump(tester, screen);
      final field = find.byKey(
        Key(
          screen is MealRecordScreen
              ? 'meal-product-field'
              : 'category-diary-note-field',
        ),
      );
      await tester.enterText(field, 'keep my draft');
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.text('keep my draft'), findsOneWidget);
      expect(find.text('계속 입력'), findsOneWidget);
      await tester.tap(find.text('계속 입력'));
      await tester.pumpAndSettle();
      expect(find.text('keep my draft'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  }
  testWidgets(
    'category save rejects synchronous duplicates and freezes draft on failure',
    (tester) async {
      final notifier = FakeRecords();
      await pump(
        tester,
        const RecordCategoryFormScreen(typeId: 'diary'),
        notifier: notifier,
      );
      await tester.enterText(
        find.byKey(const Key('category-diary-note-field')),
        'retained',
      );
      final save = tester
          .widget<RecordFormSubmitButton>(
            find.byKey(const Key('category-save-button')),
          )
          .onPressed;
      save();
      save();
      await tester.pump();
      expect(notifier.saves, 1);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('category-diary-note-field')),
            )
            .enabled,
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('retained'), findsOneWidget);
      notifier.pending.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text('retained'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('category-diary-note-field')),
            )
            .enabled,
        isTrue,
      );
      expect(find.textContaining('저장에 실패'), findsOneWidget);
    },
  );
  testWidgets('plain category choices keep compact accessible tap targets', (
    tester,
  ) async {
    await pump(tester, const RecordCategoryFormScreen(typeId: 'poop'));
    final size = tester.getSize(
      find.byKey(const Key('category-poop-shape-normal')),
    );
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.height, lessThan(86));
  });
}

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  FakeRecords? notifier,
  double width = 800,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => TextButton(
          onPressed: () => context.push('/form'),
          child: const Text('open'),
        ),
      ),
      GoRoute(path: '/form', builder: (_, _) => screen),
      GoRoute(
        path: '/records',
        builder: (_, _) => const Scaffold(body: Text('saved records')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => notifier ?? FakeRecords())],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// Test constructor performs no fetch; all mutation/retry methods are local.
class FakeRecords extends PetNotifier {
  FakeRecords({bool loading = false})
    : super.test(
        PetState(
          isLoading: loading,
          hasOnboarded: true,
          pets: const [],
          activePetId: 'pet',
          records: const [],
          routines: const [],
          todayRoutineItems: const [],
          routineCompletions: const {},
          quickTypeIds: const [],
        ),
      );
  int saves = 0;
  int session = 0;
  @override
  (int, int, String?) get routineContext => (session, 0, state.activePetId);
  void changeOwner({bool samePet = false}) {
    session++;
    state = state.copyWith(activePetId: samePet ? 'pet' : 'other');
  }

  void setRecords(List<ActivityRecord> records) => state = state.copyWith(
    records: records,
    isLoading: false,
    clearDataError: true,
  );
  void clearForRefresh() =>
      state = state.copyWith(records: [], isLoading: true);
  final updated = <(String, Map<String, dynamic>)>[];
  final deleted = <String>[];
  final pending = Completer<void>();
  void failLoad() =>
      state = state.copyWith(isLoading: false, dataErrorText: 'load failed');
  @override
  Future<void> retryDataLoad() async {
    state = state.copyWith(clearDataError: true);
  }

  @override
  Future<void> addRecord(
    Map<String, dynamic> body, {
    RecordPhotoUpload? photo,
  }) async {
    saves++;
    await pending.future;
  }

  @override
  Future<void> updateRecord(String id, Map<String, dynamic> body) async {
    updated.add((id, body));
    saves++;
    await pending.future;
  }

  @override
  Future<void> deleteRecord(String id) async {
    deleted.add(id);
  }
}

ActivityRecord meal(String id, String product) => ActivityRecord(
  id: id,
  petId: 'pet',
  typeId: 'meal',
  date: '2026-09-21',
  time: '09:00',
  detail: {
    'foodType': 'dry',
    'servedAmount': 30,
    'consumedPercent': 100,
    'product': product,
  },
);

class PendingPhoto extends XFile {
  PendingPhoto() : super('local-test.jpg');
  final bytes = Completer<Uint8List>();
  @override
  Future<Uint8List> readAsBytes() => bytes.future;
}
