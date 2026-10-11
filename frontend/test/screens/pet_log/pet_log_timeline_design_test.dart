import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/pet_log.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/pet_log/pet_log_screen.dart';
import 'package:frontend/screens/pet_log/pet_log_create_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    initApiClient('https://pet-log.test', includeAuthInterceptor: false);
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
    expect(find.text('2026.10.09 19:15'), findsOneWidget);
    expect(find.textContaining('보낸 산책 시간'), findsNothing);
    expect(find.text('카드를 누르면 기록 상세 예시를 볼 수 있어요.'), findsNothing);
    expect(find.text('예시 기록 삭제'), findsNothing);

    final photo = tester.getRect(find.byType(Image).first);
    expect(photo.width / photo.height, closeTo(358 / 140, 0.03));
    expect(find.byTooltip('뒤로'), findsOneWidget);
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
    expect(find.byTooltip('첫 기록 남기기'), findsOneWidget);
    expect(find.byIcon(Icons.photo_album_outlined), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first-record action stays a compact floating pencil button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTimeline(tester, exampleDismissed: true);

    final action = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(action.isExtended, isFalse);
    expect(action.tooltip, '첫 기록 남기기');
    expect(find.text('첫 기록 남기기'), findsNothing);
  });

  testWidgets('timeline timestamp uses the Figma dotted date format', (
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

    expect(find.text('2026.10.09 19:15'), findsOneWidget);
    expect(find.text('2026-10-09  19:15'), findsNothing);
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

    expect(find.text('10월 12일'), findsOneWidget);
    expect(find.text('2026년 10월 12일 월요일 01:14'), findsOneWidget);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('사진 1장'), findsOneWidget);
    expect(find.text('사진 선택'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('record book header and period row match the Figma layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    dio.httpClientAdapter = _PetLogAdapter(
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

    expect(find.byTooltip('뒤로'), findsOneWidget);
    expect(find.byTooltip('기록집 공유'), findsOneWidget);
    expect(find.text('2026년 전체'), findsOneWidget);
    expect(find.text('전체 기록'), findsOneWidget);
    expect(find.textContaining('개 기록'), findsNothing);
    expect(find.text('2026.10.09 19:15'), findsOneWidget);
    final cover = tester.getRect(find.byKey(const Key('pet-log-book-cover')));
    expect(cover.width / cover.height, closeTo(358 / 160, 0.03));
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
      yearsOverride: const [2026],
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
    await tester.tap(find.text('2026년 전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8월'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(find.text('2026년 8월'), findsOneWidget);
    expect(find.text('8월에는 남긴 기록이 없어요'), findsOneWidget);
    expect(find.text('다른 달 보기'), findsOneWidget);
    expect(find.text('전체 기록 보기'), findsOneWidget);
    expect(
      find.byKey(const Key('pet-log-month-empty-illustration')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('example detail follows the Figma delete confirmation flow', (
    tester,
  ) async {
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
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('예시 기록을 삭제할까요?'), findsOneWidget);
    expect(find.text('예시 기록이 목록에서 사라져요.'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('오늘의 사진을 골라볼까요?'), findsOneWidget);
    expect(find.text('함께한 순간을 그대로 담아주세요.'), findsOneWidget);
    expect(find.text('오늘의 이야기'), findsOneWidget);
    expect(find.text('사진 선택'), findsOneWidget);
    expect(find.text('기록 저장'), findsNothing);
    expect(find.text('저장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo editor uses compact rows with fixed completion action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PetLogPhotoEditScreen(
          photos: const [
            PetLogPhoto(
              id: '1',
              url: '',
              position: 0,
              width: 1200,
              height: 1600,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('사진 편집'), findsOneWidget);
    expect(find.text('사진 1장'), findsOneWidget);
    expect(find.textContaining('오른쪽 손잡이를 길게 눌러 순서를 바꿔요.'), findsOneWidget);
    expect(find.text('대표사진'), findsOneWidget);
    expect(find.text('원본 비율 유지'), findsOneWidget);
    expect(find.text('사진 순서 편집'), findsNothing);
    expect(find.text('완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo editor can remove all photos and add one back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    expect(find.text('사진 0장'), findsOneWidget);
    expect(find.text('첨부한 사진이 없어요.'), findsOneWidget);
    expect(find.text('사진 추가'), findsOneWidget);
    final done = tester.widget<FilledButton>(
      find.ancestor(of: find.text('완료'), matching: find.byType(FilledButton)),
    );
    expect(done.onPressed, isNull);

    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();

    expect(find.text('사진 1장'), findsOneWidget);
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
}

Future<void> _pumpTimeline(
  WidgetTester tester, {
  required bool exampleDismissed,
  List<PetLog> items = const [],
}) async {
  dio.httpClientAdapter = _PetLogAdapter(
    exampleDismissed: exampleDismissed,
    items: items,
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
