import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/core/app_v2_tokens.dart';
import 'package:frontend/widgets/app_icon.dart';
import 'package:frontend/widgets/app_action_sheet.dart';
import 'package:frontend/widgets/app_ink_well.dart';
import 'package:frontend/widgets/app_more_button.dart';
import 'package:frontend/widgets/authenticated_network_image.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/pet_log.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/services/pet_log_service.dart';
import 'package:frontend/screens/pet_log/pet_log_screen.dart';
import 'package:frontend/screens/pet_log/pet_log_create_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    initApiClient('https://pet-log.test', includeAuthInterceptor: false);
  });

  testWidgets('compact action menu matches the Figma sheet geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppActionSheet(
                context,
                presentation: AppActionSheetPresentation.compactMenu,
                actions: const [
                  AppActionSheetItem(
                    key: Key('compact-save-action'),
                    label: '저장',
                    buttonStyle: AppActionSheetButtonStyle.primary,
                  ),
                  AppActionSheetItem(
                    key: Key('compact-delete-action'),
                    label: '삭제',
                    buttonStyle: AppActionSheetButtonStyle.destructive,
                  ),
                  AppActionSheetItem(
                    key: Key('compact-cancel-action'),
                    label: '취소',
                    buttonStyle: AppActionSheetButtonStyle.secondary,
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final label = find.text('저장');
    final actionButton = find
        .ancestor(of: label, matching: find.byType(InkWell))
        .first;
    expect(tester.getSize(label).height, lessThan(30));
    expect(
      tester.getRect(label).center.dy,
      closeTo(tester.getRect(actionButton).center.dy, 1),
    );
    final save = tester.getRect(find.byKey(const Key('compact-save-action')));
    final delete = tester.getRect(
      find.byKey(const Key('compact-delete-action')),
    );
    final cancel = tester.getRect(
      find.byKey(const Key('compact-cancel-action')),
    );
    expect(save.left, closeTo(20, 0.1));
    expect(save.top, closeTo(658, 0.1));
    expect(save.width, closeTo(350, 0.1));
    expect(delete.top, closeTo(716, 0.1));
    expect(cancel.top, closeTo(774, 0.1));
    expect(cancel.bottom, closeTo(820, 0.1));
  });

  testWidgets('first-entry example matches the Figma photo-only card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTimeline(tester, exampleDismissed: false);
    await tester.pumpAndSettle();

    expect(find.text('예시'), findsOneWidget);
    expect(find.text('예시 기록'), findsNothing);
    expect(find.text('2026.10.09'), findsOneWidget);
    expect(find.textContaining('19:15'), findsNothing);
    expect(find.textContaining('보낸 산책 시간'), findsNothing);
    expect(find.text('카드를 누르면 기록 상세 예시를 볼 수 있어요.'), findsNothing);
    expect(find.text('예시 기록 삭제'), findsNothing);

    final photo = tester.getRect(find.byType(Image).first);
    expect(photo.width / photo.height, closeTo(358 / 140, 0.03));
    expect(find.byTooltip('뒤로가기'), findsOneWidget);
  });

  testWidgets('dismissed example uses the designed first-record empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTimeline(tester, exampleDismissed: true);

    expect(find.byKey(const Key('pet-log-empty-illustration')), findsOneWidget);
    expect(find.text('우리 아이의 첫 순간을\n남겨볼까요?'), findsOneWidget);
    expect(
      find.text('사진 한 장과 짧은 메모면 충분해요.\n소중한 하루를 차곡차곡 모아보세요.'),
      findsOneWidget,
    );
    expect(
      tester
              .getTopLeft(
                find.text('사진 한 장과 짧은 메모면 충분해요.\n소중한 하루를 차곡차곡 모아보세요.'),
              )
              .dy -
          tester.getBottomLeft(find.text('우리 아이의 첫 순간을\n남겨볼까요?')).dy,
      closeTo(12, 1),
    );
    expect(find.byTooltip('첫 기록 남기기'), findsOneWidget);
    expect(find.byIcon(Icons.photo_album_outlined), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty timeline shows the labeled first-record action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTimeline(tester, exampleDismissed: true);

    expect(find.text('전체 보기'), findsOneWidget);
    final action = tester.widget<FloatingActionButton>(
      find.byKey(const Key('pet-log-create-fab')),
    );
    expect(action.isExtended, isFalse);
    expect(action.tooltip, '첫 기록 남기기');
    expect(action.shape, const CircleBorder());
    expect(action.backgroundColor, AppColors.primary);
    expect(
      tester
          .widget<AppIcon>(
            find.descendant(
              of: find.byKey(const Key('pet-log-create-fab')),
              matching: find.byType(AppIcon),
            ),
          )
          .icon,
      Icons.edit,
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    final focusIndicator = tester.widget<AppFocusIndicator>(
      find.ancestor(
        of: find.byKey(const Key('pet-log-create-fab')),
        matching: find.byType(AppFocusIndicator),
      ),
    );
    expect(focusIndicator.shape, const CircleBorder());
    expect(focusIndicator.filled, isTrue);
    expect(find.text('첫 기록 남기기'), findsOneWidget);
  });

  testWidgets('timeline shows the Figma dotted date without a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTimeline(
      tester,
      exampleDismissed: false,
      items: const [
        PetLog(
          id: 'log-1',
          petId: '1',
          date: '2026-10-09',
          time: '19:15:00',
          photos: [],
          version: 1,
        ),
      ],
    );

    expect(find.text('2026.10.09'), findsOneWidget);
    expect(find.textContaining('19:15'), findsNothing);
  });

  testWidgets('record detail uses the Figma title, date, and photo action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: PetLogDetailScreen(
          log: PetLog(
            id: 'log-1',
            petId: '1',
            date: '2026-10-12',
            time: '01:14:00',
            photos: [
              PetLogPhoto(
                id: 'photo-1',
                url: '',
                position: 0,
                width: 350,
                height: 350,
              ),
            ],
            version: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('기록 상세'), findsOneWidget);
    expect(find.text('10월 12일'), findsNothing);
    expect(find.text('2026년 10월 12일 월요일'), findsNothing);
    expect(find.textContaining('01:14'), findsNothing);
    expect(find.text('수정'), findsOneWidget);
    final editButton = tester.widget<TextButton>(
      find.byKey(const Key('pet-log-detail-edit')),
    );
    expect(editButton.style!.foregroundColor!.resolve({}), AppColors.onPrimary);
    expect(
      find.ancestor(
        of: find.byKey(const Key('pet-log-detail-edit')),
        matching: find.byKey(const Key('pet-log-detail-photo-action')),
      ),
      findsOneWidget,
    );
    expect(find.text('사진 1장'), findsOneWidget);
    expect(find.text('사진 선택'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byType(AppMoreButton), findsNothing);
    expect(find.byTooltip('기록 더보기'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('detail photo action opens the Figma photo selection flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: PetLogDetailScreen(
          log: PetLog(
            id: 'log-1',
            petId: '1',
            date: '2026-10-09',
            time: '19:15:00',
            note: '햇살이 좋았던 날.',
            photos: [
              PetLogPhoto(
                id: 'photo-1',
                url: '',
                position: 0,
                width: 350,
                height: 350,
              ),
              PetLogPhoto(
                id: 'photo-2',
                url: '',
                position: 1,
                width: 350,
                height: 231,
              ),
              PetLogPhoto(
                id: 'photo-3',
                url: '',
                position: 2,
                width: 350,
                height: 350,
              ),
            ],
            version: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final secondDetailPhoto = tester.widget<AuthenticatedNetworkImage>(
      find.descendant(
        of: find.byKey(const ValueKey('pet-log-photo-photo-2')),
        matching: find.byType(AuthenticatedNetworkImage),
      ),
    );
    expect(secondDetailPhoto.width, closeTo(350, 1));
    expect(secondDetailPhoto.height, closeTo(350, 1));
    expect(secondDetailPhoto.fit, BoxFit.contain);

    await tester.tap(find.text('사진 선택'));
    await tester.pumpAndSettle();

    expect(find.text('사진 선택'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('2026년 10월 9일 금요일'), findsOneWidget);
    expect(find.text('전체 선택'), findsOneWidget);
    expect(find.text('사진을 선택해주세요'), findsOneWidget);
    expect(
      find.byKey(const Key('pet-log-select-photo-photo-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pet-log-select-photo-photo-1')));
    await tester.pumpAndSettle();
    expect(find.text('1장 휴대폰에 저장'), findsOneWidget);
    final photoSaveButton = tester.widget<FilledButton>(
      find.byKey(const Key('pet-log-photo-select-save')),
    );
    expect(
      photoSaveButton.style!.foregroundColor!.resolve({}),
      AppColors.onPrimary,
    );
    expect(find.text('전체 선택'), findsOneWidget);

    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    expect(find.text('3장 휴대폰에 저장'), findsOneWidget);
    expect(find.text('전체 해제'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('pet-log-photo-select-scroll')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(find.text('햇살이 좋았던 날.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'photo viewer matches the Figma date and previous/next controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: PetLogDetailScreen(
            log: PetLog(
              id: 'log-1',
              petId: '1',
              date: '2026-10-12',
              time: '00:00:00',
              photos: [
                PetLogPhoto(
                  id: 'photo-1',
                  url: '',
                  position: 0,
                  width: 1200,
                  height: 1600,
                ),
                PetLogPhoto(
                  id: 'photo-2',
                  url: '',
                  position: 1,
                  width: 1600,
                  height: 1200,
                ),
              ],
              version: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pet-log-photo-photo-1')));
      await tester.pumpAndSettle();

      final viewer = tester.widget<Scaffold>(
        find.byKey(const Key('pet-log-photo-viewer')),
      );
      expect(viewer.backgroundColor, Colors.white);
      expect(find.text('1 / 2'), findsNWidgets(2));
      expect(find.text('2026.10.12'), findsOneWidget);
      expect(find.byTooltip('이전 사진'), findsOneWidget);
      expect(find.byTooltip('다음 사진'), findsOneWidget);

      await tester.tap(find.byTooltip('다음 사진'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('record book header and period row match the Figma layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    dio.httpClientAdapter = _PetLogAdapter(
      exampleDismissed: false,
      yearsOverride: const [2026, 2025],
      items: const [
        PetLog(
          id: 'log-1',
          petId: '1',
          date: '2026-10-09',
          time: '19:15:00',
          photos: [],
          version: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petProvider.overrideWith(
            (_) => PetNotifier.test(
              PetState(
                isLoading: false,
                hasOnboarded: true,
                pets: const [
                  Pet(
                    id: '1',
                    name: 'Mumu',
                    species: 'dog',
                    birthDate: null,
                    accentColor: '#32B982',
                    bgLight: '#F3FBF7',
                  ),
                ],
                activePetId: '1',
                records: const [],
                routines: const [],
                schedules: const [],
                todayRoutineItems: const [],
                routineCompletions: const {},
                quickTypeIds: const [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: PetLogBookScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('뒤로가기'), findsOneWidget);
    expect(find.byTooltip('기록집 공유'), findsOneWidget);
    final yearLabel = '${DateTime.now().year}년 전체';
    expect(find.text(yearLabel), findsOneWidget);
    expect(find.text('전체 기록'), findsNothing);
    expect(find.textContaining('개 기록'), findsNothing);
    final periodChip = find
        .ancestor(of: find.text(yearLabel), matching: find.byType(InkWell))
        .first;
    expect(tester.getSize(periodChip).width, 182);
    expect(tester.getSize(periodChip).height, 36);
    final calendar = find.descendant(
      of: periodChip,
      matching: find.byIcon(Icons.calendar_month_outlined),
    );
    expect(
      tester.getRect(find.text(yearLabel)).center.dx,
      lessThan(tester.getRect(calendar).center.dx),
    );
    expect(find.text('2026.10.09'), findsOneWidget);
    final cover = tester.getRect(find.byKey(const Key('pet-log-book-cover')));
    expect(cover.width / cover.height, closeTo(358 / 160, 0.03));

    await tester.tap(find.text(yearLabel));
    await tester.pumpAndSettle();
    expect(find.text('기간 설정'), findsOneWidget);
    expect(find.byKey(const Key('pet-log-book-month-1')), findsOneWidget);
    expect(find.byKey(const Key('pet-log-book-month-12')), findsOneWidget);
    final applyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '적용'),
    );
    expect(
      applyButton.style!.foregroundColor!.resolve({}),
      AppColors.onPrimary,
    );
    await tester.tap(find.text('10월'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('10월')).style!.color,
      AppColors.onPrimary,
    );

    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    final narrowMonth = tester.getRect(
      find.byKey(const Key('pet-log-book-month-12')),
    );
    expect(narrowMonth.width, closeTo(72.5, 0.1));
    expect(narrowMonth.right, lessThanOrEqualTo(340));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('pet-log-book-month-1'))),
      const Size(80, 44),
    );
    final month1 = tester.getRect(
      find.byKey(const Key('pet-log-book-month-1')),
    );
    final month2 = tester.getRect(
      find.byKey(const Key('pet-log-book-month-2')),
    );
    final month5 = tester.getRect(
      find.byKey(const Key('pet-log-book-month-5')),
    );
    expect(month2.center.dx - month1.center.dx, closeTo(90, 0.1));
    expect(month5.center.dy - month1.center.dy, closeTo(52, 0.1));
    await tester.tap(find.text('${DateTime.now().month}월'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    final monthLabel = '${DateTime.now().year}년 ${DateTime.now().month}월';
    expect(find.text(monthLabel), findsOneWidget);
    await tester.tap(find.text(monthLabel));
    await tester.pumpAndSettle();

    expect(find.text('기간 설정'), findsOneWidget);
    expect(
      find.byKey(Key('pet-log-book-month-${DateTime.now().month}')),
      findsOneWidget,
    );
    expect(find.text('연도 선택'), findsNothing);
    await tester.tap(find.text('${DateTime.now().year}년'));
    await tester.pumpAndSettle();
    expect(find.text('연도 선택'), findsOneWidget);
    expect(find.text('${DateTime.now().year}년'), findsOneWidget);
    expect(find.text('${DateTime.now().year - 1}년'), findsOneWidget);
    expect(find.text('적용'), findsNothing);
    expect(find.text('닫기'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('${DateTime.now().year - 1}년'));
    await tester.pumpAndSettle();
    expect(find.text('${DateTime.now().year - 1}년 전체'), findsOneWidget);
  });

  testWidgets(
    'record book with no records uses its designed first-record state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      dio.httpClientAdapter = _PetLogAdapter(
        exampleDismissed: true,
        items: const [],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petProvider.overrideWith(
              (_) => PetNotifier.test(
                PetState(
                  isLoading: false,
                  hasOnboarded: true,
                  pets: const [
                    Pet(
                      id: '1',
                      name: 'Mumu',
                      species: 'dog',
                      birthDate: null,
                      accentColor: '#32B982',
                      bgLight: '#F3FBF7',
                    ),
                  ],
                  activePetId: '1',
                  records: const [],
                  routines: const [],
                  schedules: const [],
                  todayRoutineItems: const [],
                  routineCompletions: const {},
                  quickTypeIds: const [],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: PetLogBookScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('아직 모아둔 기록이 없어요'), findsOneWidget);
      expect(find.text('사진과 이야기를 남기면 이곳에 날짜별로 모아볼 수 있어요.'), findsOneWidget);
      expect(
        find.byKey(const Key('pet-log-book-empty-illustration')),
        findsOneWidget,
      );
      expect(find.text('첫 기록 남기기'), findsOneWidget);
      expect(find.text('2026년 전체'), findsNothing);
      expect(find.byTooltip('기록집 공유'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected month with no records shows month-specific actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    dio.httpClientAdapter = _PetLogAdapter(
      exampleDismissed: false,
      items: const [],
      hasAnyOverride: true,
      yearsOverride: [DateTime.now().year, DateTime.now().year - 1],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petProvider.overrideWith(
            (_) => PetNotifier.test(
              PetState(
                isLoading: false,
                hasOnboarded: true,
                pets: const [
                  Pet(
                    id: '1',
                    name: 'Mumu',
                    species: 'dog',
                    birthDate: null,
                    accentColor: '#32B982',
                    bgLight: '#F3FBF7',
                  ),
                ],
                activePetId: '1',
                records: const [],
                routines: const [],
                schedules: const [],
                todayRoutineItems: const [],
                routineCompletions: const {},
                quickTypeIds: const [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: PetLogBookScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final periodLabel = '${DateTime.now().year}년 전체';
    await tester.tap(find.text(periodLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8월'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(find.text('${DateTime.now().year}년 8월'), findsOneWidget);
    expect(find.text('8월에는 남긴 기록이 없어요'), findsOneWidget);
    expect(find.text('다른 달 보기'), findsOneWidget);
    expect(find.text('다른 달의 순간을 찾아보거나\n전체 기록을 한 번에 둘러보세요.'), findsOneWidget);
    expect(
      find.text('전체 보기'),
      findsNWidgets(2),
    ); // Header and empty-state action.
    expect(
      find.byKey(const Key('pet-log-month-empty-illustration')),
      findsOneWidget,
    );
    final illustration = tester.getRect(
      find.byKey(const Key('pet-log-month-empty-illustration')),
    );
    final emptyTitle = find.text('8월에는 남긴 기록이 없어요');
    expect(
      tester.getTopLeft(emptyTitle).dy - illustration.top,
      closeTo(152, 1),
    );
    expect(tester.widget<Text>(emptyTitle).style!.fontSize, 22);
    expect(
      tester
          .widget<Text>(find.text('다른 달의 순간을 찾아보거나\n전체 기록을 한 번에 둘러보세요.'))
          .style!
          .fontSize,
      14,
    );
    final otherMonthButton = find.ancestor(
      of: find.text('다른 달 보기'),
      matching: find.byType(FilledButton),
    );
    final allRecordsButton = find.ancestor(
      of: find.text('전체 보기'),
      matching: find.byType(FilledButton),
    );
    expect(tester.getSize(otherMonthButton), const Size(350, 48));
    expect(tester.getSize(allRecordsButton), const Size(350, 48));
    expect(
      tester.getTopLeft(allRecordsButton).dy -
          tester.getBottomLeft(otherMonthButton).dy,
      closeTo(14, 1),
    );
    await tester.tap(allRecordsButton);
    await tester.pumpAndSettle();
    expect(find.text('전체 기간'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'example detail keeps destructive actions out of the detail bar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: PetLogExampleDetailScreen(petId: '1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('10월 9일'), findsOneWidget);
      expect(find.text('예시 화면입니다.'), findsOneWidget);
      expect(find.textContaining('이 예시 기록은 원할 때 삭제할 수 있어요.'), findsOneWidget);
      expect(find.text('내 기록 남기기'), findsOneWidget);
      expect(find.text('삭제'), findsNothing);
      expect(find.byType(AppMoreButton), findsNothing);
      expect(find.byTooltip('예시 기록 더보기'), findsNothing);
      expect(find.text('예시 기록을 삭제할까요?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new record empty state follows the Figma writing layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    dio.httpClientAdapter = _PetLogAdapter(
      exampleDismissed: false,
      items: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petProvider.overrideWith(
            (_) => PetNotifier.test(
              PetState(
                isLoading: false,
                hasOnboarded: true,
                pets: const [
                  Pet(
                    id: '1',
                    name: 'Mumu',
                    species: 'dog',
                    birthDate: null,
                    accentColor: '#32B982',
                    bgLight: '#F3FBF7',
                  ),
                ],
                activePetId: '1',
                records: const [],
                routines: const [],
                schedules: const [],
                todayRoutineItems: const [],
                routineCompletions: const {},
                quickTypeIds: const [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: PetLogCreateScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pet-log-empty-photo-prompt')), findsOneWidget);
    final photoPrompt = tester.widget<Container>(
      find.byKey(const Key('pet-log-empty-photo-prompt')),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('pet-log-empty-photo-prompt')))
          .height,
      276,
    );
    expect(photoPrompt.decoration, isA<BoxDecoration>());
    final photoPromptDecoration = photoPrompt.decoration! as BoxDecoration;
    expect(photoPromptDecoration.color, const Color(0xFFF3FAF6));
    expect(
      (photoPromptDecoration.border as Border).top.color,
      const Color(0xFFDCEEE4),
    );
    expect(find.text('오늘의 사진을 골라볼까요?'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('오늘의 사진을 골라볼까요?')).style!.fontSize,
      18,
    );
    expect(find.text('함께한 순간을 그대로 담아주세요.'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('함께한 순간을 그대로 담아주세요.')).style!.fontSize,
      13,
    );
    final illustration = find.descendant(
      of: find.byKey(const Key('pet-log-empty-photo-prompt')),
      matching: find.byType(SvgPicture),
    );
    expect(tester.getSize(illustration), const Size(128, 100));
    expect(find.text('오늘의 이야기'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.edit_outlined).first).color,
      AppColors.primary,
    );
    expect(find.text('사진 추가'), findsOneWidget);
    final photoSelectButton = find
        .ancestor(
          of: find.text('사진 추가').first,
          matching: find.byType(FilledButton),
        )
        .first;
    expect(tester.getSize(photoSelectButton), const Size(150, 44));
    final storyField = tester.widget<TextField>(find.byType(TextField));
    expect(storyField.decoration!.counterText, '');
    expect(tester.getSize(find.byType(TextField)).height, 114);
    expect(find.text('0/2000'), findsNothing);
    expect(
      find.ancestor(
        of: find.text('사진을 담고, 오늘의 기록을 저장해요'),
        matching: find.byKey(const Key('pet-log-create-footer')),
      ),
      findsOneWidget,
    );
    expect(find.text('기록 저장'), findsNothing);
    expect(find.text('저장'), findsOneWidget);

    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();
    expect(find.text('사진 추가'), findsNWidgets(2));
    expect(find.text('사진 보관함'), findsOneWidget);
    expect(find.text('저장된 사진에서 선택'), findsOneWidget);
    expect(find.text('카메라'), findsOneWidget);
    expect(find.text('지금 촬영해서 추가'), findsOneWidget);
    final galleryCard = tester.widget<Material>(
      find
          .ancestor(of: find.text('사진 보관함'), matching: find.byType(Material))
          .first,
    );
    expect(galleryCard.color, AppV2Tokens.mintSurface);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('record edit actions are grouped in the more menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const log = PetLog(
      id: 'log-1',
      petId: '1',
      date: '2026-10-09',
      time: '00:00:00',
      photos: [
        PetLogPhoto(
          id: 'photo-1',
          url: '',
          position: 0,
          width: 1200,
          height: 1600,
        ),
        PetLogPhoto(
          id: 'photo-2',
          url: '',
          position: 1,
          width: 1600,
          height: 1200,
        ),
      ],
      version: 1,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petProvider.overrideWith(
            (_) => PetNotifier.test(
              PetState(
                isLoading: false,
                hasOnboarded: true,
                pets: const [
                  Pet(
                    id: '1',
                    name: 'Mumu',
                    species: 'dog',
                    birthDate: null,
                    accentColor: '#32B982',
                    bgLight: '#F3FBF7',
                  ),
                ],
                activePetId: '1',
                records: const [],
                routines: const [],
                schedules: const [],
                todayRoutineItems: const [],
                routineCompletions: const {},
                quickTypeIds: const [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: PetLogCreateScreen(editing: log)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026년 10월 9일 금요일'), findsNothing);
    expect(find.text('사진 편집'), findsOneWidget);
    expect(find.text('사진 2장'), findsNothing);
    expect(find.text('기록 삭제'), findsNothing);
    expect(find.byKey(const Key('pet-log-edit-more')), findsOneWidget);
    expect(find.byKey(const Key('pet-log-edit-footer')), findsOneWidget);
    expect(
      find.byKey(const Key('pet-log-edit-footer-photo-edit')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pet-log-edit-footer-date-change')),
      findsOneWidget,
    );
    final more = tester.getRect(find.byKey(const Key('pet-log-edit-more')));
    expect(find.widgetWithText(TextButton, '저장'), findsNothing);
    expect(more.right, closeTo(352, 1));
    final firstPhotoSize = tester.getSize(
      find.byKey(const ValueKey('existing-photo-1')),
    );
    expect(firstPhotoSize.width, closeTo(320, 1));
    expect(firstPhotoSize.height, closeTo(320 / (1200 / 1600) + 10, 1));

    await tester.tap(find.byKey(const Key('pet-log-edit-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pet-log-edit-menu-photo-edit')), findsNothing);
    expect(
      find.byKey(const Key('pet-log-edit-menu-date-change')),
      findsNothing,
    );
    expect(find.byKey(const Key('pet-log-edit-menu-save')), findsOneWidget);
    expect(find.byKey(const Key('pet-log-edit-menu-delete')), findsOneWidget);
    expect(find.byKey(const Key('pet-log-edit-menu-cancel')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('pet-log-edit-menu-save'))),
      const Size(320, 50),
    );
    expect(
      tester.getSize(find.byKey(const Key('pet-log-edit-menu-delete'))),
      const Size(320, 50),
    );
    expect(
      tester.getSize(find.byKey(const Key('pet-log-edit-menu-cancel'))),
      const Size(320, 46),
    );
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pet-log-edit-footer-date-change')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-date-year-wheel')), findsOneWidget);
    expect(find.byKey(const Key('record-date-month-wheel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('record-picker-cancel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pet-log-edit-footer-photo-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();
    expect(find.text('사진 보관함'), findsOneWidget);
    expect(find.text('카메라'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    final galleryCard = tester.widget<Material>(
      find
          .ancestor(of: find.text('사진 보관함'), matching: find.byType(Material))
          .first,
    );
    expect(galleryCard.color, AppV2Tokens.mintSurface);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo editor uses compact rows with fixed completion action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    const photo = PetLogPhoto(
      id: '1',
      url: '',
      position: 0,
      width: 1200,
      height: 1600,
    );
    const addedPhoto = PetLogPhoto(
      id: '2',
      url: '',
      position: 1,
      width: 1200,
      height: 1600,
    );
    const thirdPhoto = PetLogPhoto(
      id: '3',
      url: '',
      position: 2,
      width: 1200,
      height: 1600,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PetLogPhotoEditScreen(
          photos: const [photo, addedPhoto],
          onAddPhotos: (_) async => [thirdPhoto],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('사진 편집'), findsOneWidget);
    expect(find.text('사진 2장'), findsNothing);
    expect(find.textContaining('오른쪽 손잡이를 길게 눌러'), findsNothing);
    expect(find.text('사진 추가'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('pet-log-photo-add'))).dy,
      closeTo(696, 1),
    );
    expect(find.text('대표사진'), findsOneWidget);
    expect(find.text('원본 비율 유지'), findsNothing);
    final firstPhotoImage = tester.widget<AuthenticatedNetworkImage>(
      find.descendant(
        of: find.byKey(const ValueKey('photo-1')),
        matching: find.byType(AuthenticatedNetworkImage),
      ),
    );
    expect(firstPhotoImage.fit, BoxFit.contain);
    final addPhotosButton = tester.widget<FilledButton>(
      find.byKey(const Key('pet-log-photo-add')),
    );
    expect(
      addPhotosButton.style!.foregroundColor!.resolve({}),
      AppColors.onPrimary,
    );
    final completeButton = tester.widget<FilledButton>(
      find.ancestor(of: find.text('완료'), matching: find.byType(FilledButton)),
    );
    expect(
      completeButton.style!.foregroundColor!.resolve({}),
      AppColors.onPrimary,
    );
    expect(
      find.byKey(const Key('pet-log-photo-reorder-line-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pet-log-photo-reorder-line-0-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pet-log-photo-reorder-line-0-2')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const Key('pet-log-photo-reorder-hit-target-0')),
      ),
      const Size(44, 44),
    );
    for (var line = 0; line < 3; line++) {
      expect(
        tester.getSize(find.byKey(Key('pet-log-photo-reorder-line-0-$line'))),
        const Size(18, 1.5),
      );
    }
    final firstGripLine = tester.getRect(
      find.byKey(const Key('pet-log-photo-reorder-line-0-0')),
    );
    final secondGripLine = tester.getRect(
      find.byKey(const Key('pet-log-photo-reorder-line-0-1')),
    );
    expect(secondGripLine.center.dy - firstGripLine.center.dy, closeTo(7, 0.1));
    expect(
      tester.getSize(
        find.byKey(const Key('pet-log-photo-remove-hit-target-1')),
      ),
      const Size(44, 44),
    );
    expect(
      tester.getSize(find.byKey(const Key('pet-log-photo-remove-visual-1'))),
      const Size(18, 18),
    );
    final removeVisual = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('pet-log-photo-remove-visual-1')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (removeVisual.decoration as BoxDecoration).border,
      Border.all(color: AppColors.border),
    );
    expect(find.text('사진 순서 편집'), findsNothing);
    expect(find.text('사진 편집'), findsOneWidget);
    final firstRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('photo-1')))
        .dy;
    final secondRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('photo-2')))
        .dy;
    expect(firstRowTop, closeTo(92, 1));
    expect(secondRowTop - firstRowTop, closeTo(136, 1));
    expect(
      tester
          .getTopLeft(
            find.ancestor(
              of: find.text('완료'),
              matching: find.byType(FilledButton),
            ),
          )
          .dy,
      closeTo(754, 1),
    );

    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();
    expect(find.text('사진 3장'), findsNothing);
    expect(find.text('완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo editor can remove all photos and add one back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    final photo = const PetLogPhoto(
      id: '1',
      url: '',
      position: 0,
      width: 1200,
      height: 1600,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PetLogPhotoEditScreen(
          photos: [photo],
          onAddPhotos: (_) async => [photo],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('사진 삭제'));
    await tester.pumpAndSettle();

    expect(find.text('사진 0장'), findsNothing);
    expect(find.text('첨부한 사진이 없어요'), findsOneWidget);
    expect(find.text('첨부한 사진이 없어요.'), findsNothing);
    expect(find.text('기록에 담을 사진을 한 장 이상 추가해주세요.'), findsNothing);
    expect(
      find.text('완료하면 작성 화면에 반영돼요. 기록의 저장 버튼을 눌러야 최종 저장돼요.'),
      findsNothing,
    );
    expect(find.text('사진 추가'), findsOneWidget);
    expect(tester.getTopLeft(find.text('첨부한 사진이 없어요')).dy, closeTo(238, 1));
    expect(
      tester.getTopLeft(find.byKey(const Key('pet-log-photo-add'))).dy,
      closeTo(696, 1),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('pet-log-photo-add'))).dy,
      lessThan(tester.getTopLeft(find.text('완료')).dy),
    );
    expect(
      tester
          .getTopLeft(
            find.ancestor(
              of: find.text('완료'),
              matching: find.byType(FilledButton),
            ),
          )
          .dy,
      closeTo(754, 1),
    );
    final done = tester.widget<FilledButton>(
      find.ancestor(of: find.text('완료'), matching: find.byType(FilledButton)),
    );
    expect(done.onPressed, isNull);

    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();

    expect(find.text('사진 1장'), findsNothing);
    expect(find.text('대표사진'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('완료'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unknown save outcome locks edits that would change its retry payload',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      dio.httpClientAdapter = _UnknownUpdateAdapter();

      const log = PetLog(
        id: '7',
        petId: '1',
        date: '2026-10-12',
        time: '10:24:00',
        photos: [
          PetLogPhoto(id: '21', url: '', position: 0, width: 350, height: 350),
        ],
        note: '기존 이야기',
        version: 3,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petProvider.overrideWith(
              (_) => PetNotifier.test(
                const PetState(
                  isLoading: false,
                  hasOnboarded: true,
                  pets: [
                    Pet(
                      id: '1',
                      name: 'Mumu',
                      species: 'dog',
                      birthDate: null,
                      accentColor: '#32B982',
                      bgLight: '#F3FBF7',
                    ),
                  ],
                  activePetId: '1',
                  records: [],
                  routines: [],
                  schedules: [],
                  todayRoutineItems: [],
                  routineCompletions: {},
                  quickTypeIds: [],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: PetLogCreateScreen(editing: log)),
        ),
      );

      await tester.enterText(find.byType(TextField), '변경한 이야기');
      await tester.tap(find.byKey(const Key('pet-log-edit-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pet-log-edit-menu-save')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('pet-log-edit-footer-photo-edit')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('pet-log-edit-footer-date-change')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh failure clears the spinner for an obsolete page request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [
        for (var index = 0; index < 20; index++)
          PetLog(
            id: '$index',
            petId: '1',
            date: '2026-10-${(20 - index).toString().padLeft(2, '0')}',
            time: '10:00:00',
            photos: const [],
            version: 1,
          ),
      ];
      final adapter = _OverlappingReloadAdapter(items);
      await _pumpTimeline(
        tester,
        exampleDismissed: true,
        items: items,
        adapter: adapter,
      );

      expect(find.text('2026.10.20'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('2026.10.01'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(adapter.nextPageStarted.isCompleted, isTrue);

      PetLogService.notifyChanged();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(adapter.firstPageCalls, 3);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      adapter.finishNextPage();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}

Future<void> _pumpTimeline(
  WidgetTester tester, {
  required bool exampleDismissed,
  List<PetLog> items = const [],
  HttpClientAdapter? adapter,
}) async {
  dio.httpClientAdapter =
      adapter ??
      _PetLogAdapter(exampleDismissed: exampleDismissed, items: items);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith(
          (_) => PetNotifier.test(
            PetState(
              isLoading: false,
              hasOnboarded: true,
              pets: const [
                Pet(
                  id: '1',
                  name: 'Mumu',
                  species: 'dog',
                  birthDate: null,
                  accentColor: '#32B982',
                  bgLight: '#F3FBF7',
                ),
              ],
              activePetId: '1',
              records: const [],
              routines: const [],
              schedules: const [],
              todayRoutineItems: const [],
              routineCompletions: const {},
              quickTypeIds: const [],
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: PetLogScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _PetLogAdapter implements HttpClientAdapter {
  _PetLogAdapter({
    required this.exampleDismissed,
    required this.items,
    this.hasAnyOverride,
    this.yearsOverride,
  });

  final bool exampleDismissed;
  final List<PetLog> items;
  final bool? hasAnyOverride;
  final List<int>? yearsOverride;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = options.path.endsWith('/preferences')
        ? {'data': exampleDismissed}
        : {
            'data': {
              'items': items
                  .map(
                    (item) => {
                      'id': item.id,
                      'petId': item.petId,
                      'date': item.date,
                      'time': item.time,
                      'photos': <Object>[],
                      'version': item.version,
                    },
                  )
                  .toList(),
              'years': yearsOverride ?? (items.isEmpty ? <int>[] : <int>[2026]),
              'hasAny': hasAnyOverride ?? items.isNotEmpty,
              'nextCursor': null,
            },
          };
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UnknownUpdateAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"title":"Temporary server failure"}',
    500,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _OverlappingReloadAdapter implements HttpClientAdapter {
  _OverlappingReloadAdapter(this.items);

  final List<PetLog> items;
  final nextPageStarted = Completer<void>();
  final _nextPageCompleter = Completer<void>();
  int _firstPageCalls = 0;
  int get firstPageCalls => _firstPageCalls;

  void finishNextPage() => _nextPageCompleter.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/preferences')) {
      return _jsonResponse({'data': true});
    }
    if (options.queryParameters['cursor'] == 'next-page') {
      if (!nextPageStarted.isCompleted) nextPageStarted.complete();
      await _nextPageCompleter.future;
      return _jsonResponse({
        'data': {
          'items': <Object>[],
          'years': [2026],
          'hasAny': true,
          'nextCursor': null,
        },
      });
    }
    _firstPageCalls++;
    if (_firstPageCalls == 1) {
      return _jsonResponse({
        'data': {
          'items': [
            for (final item in items)
              {
                'id': item.id,
                'petId': item.petId,
                'date': item.date,
                'time': item.time,
                'photos': <Object>[],
                'version': item.version,
              },
          ],
          'years': [2026],
          'hasAny': true,
          'nextCursor': 'next-page',
        },
      });
    }
    return _jsonResponse({'title': 'Temporary server failure'}, status: 500);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
