import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/widgets/app_ink_well.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/routine/routine_create_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('notification switch updates the saved setting directly', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState());
    await _pumpScreen(tester, notifier, editingRoutine: _editFixture());
    final toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    final semantics = tester.ensureSemantics();
    try {
      expect(tester.getSemantics(toggle).label, '알림 받기');
    } finally {
      semantics.dispose();
    }
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await _tapSave(tester);
    expect(notifier.updatedRoutineBody?['notificationEnabled'], false);
  });
  for (final width in [320.0, 375.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('routine controls remain reachable at $width and $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpScreen(
          tester,
          _FakePetNotifier(_petState()),
          editingRoutine: _editFixture(times: ['08:00', '20:00']),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final remove = find.byKey(const Key('routine-time-field'));
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        expect(tester.getSize(remove).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(
          find.byKey(const Key('routine-add-time-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('routine-add-time-button')).hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'failed confirmation reload is a connection error and keeps the form',
    (tester) async {
      final notifier = _FakePetNotifier(
        _petState(),
        updateError: ApiException(statusCode: 400, title: 'Invalid'),
      )..reloadError = Exception('offline');
      await _pumpScreen(tester, notifier, editingRoutine: _editFixture());
      await tester.enterText(
        find.byKey(const Key('routine-name-field')),
        '보존할 제목',
      );
      await _tapSave(tester);
      expect(find.text('루틴을 찾을 수 없습니다.'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('routine-name-field')))
            .controller!
            .text,
        '보존할 제목',
      );
      expect(
        find.text('연결 상태를 확인한 뒤 다시 시도해 주세요. 입력 내용은 유지됩니다.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('late save after screen disposal does not navigate or throw', (
    tester,
  ) async {
    final gate = Completer<void>();
    final notifier = _FakePetNotifier(_petState(), saveGate: gate);
    await _pumpScreen(tester, notifier, editingRoutine: _editFixture());
    await tester.enterText(find.byKey(const Key('routine-name-field')), '저장');
    await tester.pump();
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
    await tester.pump();
    await tester.pump();
    expect(notifier.updateCalls, 1);
    await tester.pumpWidget(const MaterialApp(home: Text('다른 화면')));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('다른 화면'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('direct edit loads once and refresh cannot overwrite draft', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState())..reloaded = [_editFixture()];
    await _pumpScreen(tester, notifier, editRoute: true);
    expect(notifier.reloadCalls, 1);
    await tester.enterText(find.byKey(const Key('routine-name-field')), '작성 중');
    notifier.reloaded = [_editFixture(note: 'server changed')];
    await notifier.reloadRoutines();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('routine-name-field')))
          .controller!
          .text,
      '작성 중',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('routine-note-field')))
          .controller!
          .text,
      '',
    );
  });
  testWidgets('direct edit failure retries without reporting missing target', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState())
      ..reloadError = Exception('offline');
    await _pumpScreen(tester, notifier, editRoute: true);
    expect(find.text('루틴을 찾을 수 없습니다.'), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
    notifier.reloadError = null;
    notifier.reloaded = [_editFixture()];
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine-name-field')), findsOneWidget);
    expect(notifier.reloadCalls, 2);
  });
  testWidgets(
    'narrow large-text layout keeps save and time controls reachable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpScreen(
        tester,
        _FakePetNotifier(_petState()),
        editingRoutine: _editFixture(times: ['08:00', '20:00']),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const Key('routine-add-time-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('routine-add-time-button')).hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty legacy times can add then remove back to unchanged', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState());
    await _pumpScreen(
      tester,
      notifier,
      editingRoutine: _editFixture(times: []),
    );
    await tester.ensureVisible(
      find.byKey(const Key('routine-add-time-button')),
    );
    await tester.tap(find.byKey(const Key('routine-add-time-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('routine-time-field')));
    await tester.tap(find.byKey(const Key('routine-time-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 시간 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('등록된 시간이 없어 예약 알림이 발송되지 않아요.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
  testWidgets('additional time is sorted and sent with all existing times', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState());
    await _pumpScreen(
      tester,
      notifier,
      editingRoutine: _editFixture(times: ['20:00']),
    );
    await tester.ensureVisible(
      find.byKey(const Key('routine-add-time-button')),
    );
    await tester.tap(find.byKey(const Key('routine-add-time-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(notifier.updatedRoutineBody, {
      'times': ['08:00', '20:00'],
    });
  });
  testWidgets(
    'delete confirmation locks duplicate confirmation and save until canceled',
    (tester) async {
      final notifier = _FakePetNotifier(_petState());
      await _pumpScreen(tester, notifier, editingRoutine: _editFixture());
      await tester.enterText(find.byKey(const Key('routine-name-field')), '변경');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      final remove = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('routine-delete-button')),
          )
          .onPressed!;
      remove();
      remove();
      save();
      await tester.pumpAndSettle();
      expect(find.text('루틴을 삭제할까요?'), findsOneWidget);
      expect(notifier.updateCalls, 0);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await _tapSave(tester);
      expect(notifier.updateCalls, 1);
    },
  );
  testWidgets('system back confirms unsaved edits and cancel preserves input', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakePetNotifier(_petState()),
      editingRoutine: _editFixture(),
    );
    await tester.enterText(find.byKey(const Key('routine-name-field')), '미저장');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('변경 내용을 버릴까요?'), findsOneWidget);
    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('routine-name-field')))
          .controller!
          .text,
      '미저장',
    );
  });
  testWidgets('400 preserves input when target exists and 403 is distinct', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(
      _petState(),
      updateError: ApiException(
        statusCode: 400,
        title: 'Invalid',
        errorCode: 'INVALID_INPUT',
      ),
    );
    notifier.reloaded = [_editFixture()];
    await _pumpScreen(tester, notifier, editingRoutine: _editFixture());
    await tester.enterText(
      find.byKey(const Key('routine-name-field')),
      '입력 유지',
    );
    await _tapSave(tester);
    expect(notifier.reloadCalls, 1);
    expect(find.text('루틴을 찾을 수 없습니다.'), findsNothing);
    notifier.updateError = ApiException(statusCode: 403, title: 'Forbidden');
    await _tapSave(tester);
    expect(find.text('이 루틴에 접근할 수 없어요.'), findsOneWidget);
    expect(notifier.reloadCalls, 1);
  });
  testWidgets('400 with successful empty reload shows missing target', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(
      _petState(),
      updateError: ApiException(statusCode: 400, title: 'Invalid'),
    );
    await _pumpScreen(tester, notifier, editingRoutine: _editFixture());
    await tester.enterText(find.byKey(const Key('routine-name-field')), '변경');
    await _tapSave(tester);
    expect(find.text('루틴을 찾을 수 없습니다.'), findsOneWidget);
  });
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('repeat and day focus rings follow the rendered chip corners', (
    tester,
  ) async {
    await _pumpScreen(tester, _FakePetNotifier(_petState()));
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '매주'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '매주'));
    await tester.pumpAndSettle();
    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .toList();
    expect(chips.length, 11);
    for (final chip in chips) {
      final finder = find.byWidget(chip);
      final indicator = tester.widget<AppFocusIndicator>(
        find
            .ancestor(of: finder, matching: find.byType(AppFocusIndicator))
            .first,
      );
      final material = tester.widget<Material>(
        find.descendant(of: finder, matching: find.byType(Material)).first,
      );
      final actualShape = material.shape! as RoundedRectangleBorder;
      expect(
        (indicator.shape as RoundedRectangleBorder).borderRadius,
        actualShape.borderRadius,
      );
      expect(actualShape.borderRadius, BorderRadius.circular(8));
    }
  });

  testWidgets(
    'category selection keeps white cards and moves the green border',
    (tester) async {
      await _pumpScreen(tester, _FakePetNotifier(_petState()));
      BoxDecoration card(String type) =>
          tester
                  .widget<Ink>(
                    find
                        .descendant(
                          of: find.byKey(Key('routine-category-$type')),
                          matching: find.byWidgetPredicate(
                            (w) => w is Ink && w.decoration is BoxDecoration,
                          ),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(card('meal').color, AppColors.surface);
      await tester.tap(find.byKey(const Key('routine-category-meal')));
      await tester.pumpAndSettle();
      expect(card('meal').color, AppColors.surface);
      expect((card('meal').border! as Border).top.color, AppColors.primary);
      expect((card('medicine').border! as Border).top.color, AppColors.border);
      expect((card('meal').border! as Border).top.width, 1.5);
      expect((card('medicine').border! as Border).top.width, 1.5);
    },
  );

  testWidgets('routine categories are inline with period fields', (
    tester,
  ) async {
    await _pumpScreen(tester, _FakePetNotifier(_petState()));

    expect(find.text('투약'), findsOneWidget);
    expect(find.text('급식'), findsOneWidget);
    expect(find.text('병원 관리'), findsOneWidget);
    expect(find.text('루틴 유형 선택'), findsNothing);
    expect(find.byKey(const Key('routine-name-field')), findsOneWidget);
    expect(find.byKey(const Key('routine-start-date-field')), findsOneWidget);
    expect(find.byKey(const Key('routine-end-date-field')), findsOneWidget);
    expect(find.text('종료일 없음'), findsOneWidget);
    expect(find.text('검진'), findsNothing);
    expect(find.text('놀이'), findsNothing);
    expect(find.text('커스텀'), findsNothing);

    final dailyChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '매일'),
    );
    final weeklyChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '매주'),
    );
    expect(dailyChip.showCheckmark, isFalse);
    expect(dailyChip.selectedColor, AppColors.primary);
    expect(weeklyChip.backgroundColor, AppColors.white);
    expect(
      dailyChip.color!.resolve({WidgetState.selected, WidgetState.hovered}),
      AppColors.primary,
    );
    expect(weeklyChip.color!.resolve({WidgetState.hovered}), AppColors.white);
    expect(
      find.byKey(const Key('routine-notification-button')),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('weekly save defaults today weekday and omits empty note', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState());
    await _pumpScreen(tester, notifier);
    await tester.tap(find.byKey(const Key('routine-category-medicine')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('routine-name-field')))
          .controller!
          .text,
      '투약',
    );
    await tester.ensureVisible(find.text('매주'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('매주'));
    await tester.pumpAndSettle();

    final todayDay = DateTime.now().weekday % 7;
    final todayChip = tester.widget<ChoiceChip>(
      find.byKey(Key('routine-day-$todayDay')),
    );
    expect(todayChip.selected, isTrue);

    await tester.ensureVisible(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(notifier.addedRoutineBody, isNotNull);
    expect(notifier.addedRoutineBody!['label'], '투약');
    expect(notifier.addedRoutineBody!['typeId'], 'medicine');
    expect(notifier.addedRoutineBody!['repeatType'], 'weekly');
    expect(notifier.addedRoutineBody!['days'], [todayDay]);
    expect(notifier.addedRoutineBody!['times'], ['08:00']);
    expect(notifier.addedRoutineBody!['notificationEnabled'], isTrue);
    expect(notifier.addedRoutineBody!.containsKey('note'), isFalse);
    expect(find.text('routine target tab=routines'), findsOneWidget);
  });

  testWidgets('routine time field opens shared time picker', (tester) async {
    await _pumpScreen(tester, _FakePetNotifier(_petState()));
    await tester.tap(find.byKey(const Key('routine-category-meal')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('routine-time-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('routine-time-field')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-time-hour-wheel')), findsOneWidget);
  });

  testWidgets('routine save failure keeps screen and shows error', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState(), failAdd: true);
    await _pumpScreen(tester, notifier);
    await tester.tap(find.byKey(const Key('routine-category-medicine')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('저장에 실패했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byType(RoutineCreateScreen), findsOneWidget);
  });
  testWidgets('editing routine explicitly clears memo and end date', (
    tester,
  ) async {
    const routine = Routine(
      id: 'r1',
      petId: '1',
      label: '급식',
      typeId: 'meal',
      repeatType: 'daily',
      times: ['08:00'],
      days: [],
      startDate: '2026-05-01',
      endDate: '2026-05-31',
      note: '기존 메모',
    );
    final notifier = _FakePetNotifier(_petState());
    await _pumpScreen(tester, notifier, editingRoutine: routine);
    final delete = tester.widget<OutlinedButton>(
      find.byKey(const Key('routine-delete-button')),
    );
    expect(
      delete.style!.overlayColor!.resolve({WidgetState.pressed}),
      AppColors.danger.withValues(alpha: .10),
    );
    expect(
      delete.style!.overlayColor!.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    final clearEnd = find.byKey(const Key('routine-end-date-field'));
    await tester.ensureVisible(clearEnd);
    await tester.pumpAndSettle();
    await tester.tap(clearEnd);
    await tester.pumpAndSettle();
    await tester.tap(find.text('종료일 없음'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('routine-note-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('routine-note-field')), '');
    await tester.pump();
    await tester.ensureVisible(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(notifier.updatedRoutineBody?['note'], '');
    expect(notifier.updatedRoutineBody?['clearEndDate'], isTrue);
  });

  testWidgets(
    'editing routine preserves and submits multiple times and interval',
    (tester) async {
      const routine = Routine(
        id: 'r2',
        petId: '1',
        label: '정기 검진',
        typeId: 'walk',
        repeatType: 'monthly',
        times: ['20:00', '08:00'],
        days: [],
        startDate: '2026-05-01',
        monthlyInterval: 3,
      );
      final notifier = _FakePetNotifier(_petState());
      await _pumpScreen(tester, notifier, editingRoutine: routine);

      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('routine-monthly-interval-field')),
            )
            .controller!
            .text,
        '3',
      );
      await tester.tap(find.byKey(const Key('routine-name-field')));
      await tester.enterText(
        find.byKey(const Key('routine-name-field')),
        '정기 검진 수정',
      );
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(notifier.updatedRoutineBody!.containsKey('times'), isFalse);
      expect(
        notifier.updatedRoutineBody!.containsKey('monthlyInterval'),
        isFalse,
      );
      expect(notifier.updatedRoutineBody!.containsKey('typeId'), isFalse);
    },
  );

  testWidgets(
    'duplicate added time is rejected and last original time cannot be removed',
    (tester) async {
      const routine = Routine(
        id: 'r3',
        petId: '1',
        label: '급식',
        typeId: 'meal',
        repeatType: 'daily',
        times: ['08:00'],
        days: [],
        startDate: '2026-05-01',
      );
      final notifier = _FakePetNotifier(_petState());
      await _pumpScreen(tester, notifier, editingRoutine: routine);
      await tester.ensureVisible(
        find.byKey(const Key('routine-add-time-button')),
      );
      await tester.tap(find.byKey(const Key('routine-add-time-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('record-time-hour-wheel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('record-picker-done')));
      await tester.pumpAndSettle();
      expect(find.text('이미 등록된 시간이에요.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('routine-time-field')));
      await tester.tap(find.byKey(const Key('routine-time-field')));
      await tester.pumpAndSettle();
      expect(find.text('이 시간 삭제'), findsNothing);
    },
  );

  testWidgets('memo only edits enable save and preserve whitespace', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState());
    await _pumpScreen(
      tester,
      notifier,
      editingRoutine: _editFixture(note: ' original '),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byKey(const Key('routine-note-field')));
    await tester.enterText(
      find.byKey(const Key('routine-note-field')),
      ' changed ',
    );
    await _tapSave(tester);
    expect(notifier.updatedRoutineBody, {'note': ' changed '});
  });

  testWidgets(
    'name only edit preserves raw memo and existing duplicate times',
    (tester) async {
      final notifier = _FakePetNotifier(_petState());
      await _pumpScreen(
        tester,
        notifier,
        editingRoutine: _editFixture(
          note: ' original ',
          times: ['08:00', '08:00'],
        ),
      );
      await tester.enterText(
        find.byKey(const Key('routine-name-field')),
        '새 제목',
      );
      await _tapSave(tester);
      expect(notifier.updatedRoutineBody, {'label': '새 제목'});
    },
  );

  testWidgets('invalid monthly interval can be abandoned for daily repeat', (
    tester,
  ) async {
    final notifier = _FakePetNotifier(_petState());
    await _pumpScreen(
      tester,
      notifier,
      editingRoutine: _editFixture(repeat: 'monthly'),
    );
    await tester.ensureVisible(
      find.byKey(const Key('routine-monthly-interval-field')),
    );
    await tester.enterText(
      find.byKey(const Key('routine-monthly-interval-field')),
      '2147483648',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text('입력값이 너무 커요'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('routine-monthly-interval-field')),
      '',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '매일'));
    await tester.tap(find.widgetWithText(ChoiceChip, '매일'));
    await _tapSave(tester);
    expect(notifier.updatedRoutineBody, {
      'repeatType': 'daily',
      'days': <int>[],
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same frame repeated save invokes service once and freezes input',
    (tester) async {
      final gate = Completer<void>();
      final notifier = _FakePetNotifier(_petState(), saveGate: gate);
      await _pumpScreen(tester, notifier, editingRoutine: _editFixture());
      await tester.enterText(
        find.byKey(const Key('routine-name-field')),
        '새 제목',
      );
      await tester.pump();
      final save = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      save();
      save();
      await tester.pump();
      await tester.pump();
      expect(notifier.updateCalls, 1);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is AbsorbPointer &&
              w.absorbing &&
              w.child is SingleChildScrollView,
        ),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('invalid saved time displays raw value and picker opens safely', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakePetNotifier(_petState()),
      editingRoutine: _editFixture(times: ['99:99']),
    );
    expect(find.text('99:99'), findsOneWidget);
    expect(find.text('잘못된 시간을 수정하거나 삭제해 주세요.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('routine-time-field')));
    await tester.tap(find.byKey(const Key('routine-time-field')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('record-picker-cancel')));
    await tester.pumpAndSettle();
  });
}

Routine _editFixture({
  String? note,
  List<String> times = const ['08:00'],
  String repeat = 'daily',
}) => Routine(
  id: 'r1',
  petId: '1',
  label: '원래 제목',
  typeId: 'meal',
  repeatType: repeat,
  times: times,
  days: const [],
  startDate: '2026-05-01',
  monthlyInterval: 3,
  note: note,
);

Future<void> _tapSave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakePetNotifier notifier, {
  Routine? editingRoutine,
  bool editRoute = false,
  double textScale = 1,
}) async {
  final router = GoRouter(
    initialLocation: '/routine/new',
    routes: [
      GoRoute(
        path: '/routine/new',
        builder: (_, _) => editRoute
            ? const RoutineEditScreen(routineId: 'r1')
            : RoutineCreateScreen(editingRoutine: editingRoutine),
      ),
      GoRoute(
        path: '/routine/:routineId',
        builder: (_, _) => const Scaffold(body: Text('routine detail')),
      ),
      GoRoute(
        path: '/routine',
        builder: (_, state) => Scaffold(
          body: Text('routine target tab=${state.uri.queryParameters['tab']}'),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => notifier)],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PetState _petState() => PetState(
  isLoading: false,
  hasOnboarded: true,
  pets: const [
    Pet(
      id: '1',
      name: 'Pet 1',
      species: 'dog',
      birthDate: '2022-03-15',
      accentColor: '#F4A460',
      bgLight: '#FFF8F0',
    ),
  ],
  activePetId: '1',
  records: const [],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

class _FakePetNotifier extends PetNotifier {
  _FakePetNotifier(
    super.initialState, {
    this.failAdd = false,
    this.saveGate,
    this.updateError,
  }) : super.test();
  final Completer<void>? saveGate;
  Object? updateError;
  int reloadCalls = 0;
  List<Routine> reloaded = [];
  Object? reloadError;
  @override
  Future<void> reloadRoutines() async {
    reloadCalls++;
    if (reloadError != null) throw reloadError!;
    state = state.copyWith(routines: reloaded);
  }

  int updateCalls = 0;

  final bool failAdd;
  Map<String, dynamic>? addedRoutineBody;
  Map<String, dynamic>? updatedRoutineBody;

  @override
  Future<bool> updateRoutine(String id, Map<String, dynamic> body) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
    updatedRoutineBody = body;
    if (saveGate != null) await saveGate!.future;
    return true;
  }

  @override
  Future<bool> addRoutine(Map<String, dynamic> body) async {
    if (failAdd) throw Exception('failed');
    addedRoutineBody = body;
    return true;
  }
}
