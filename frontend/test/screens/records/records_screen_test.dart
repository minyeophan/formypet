import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/records/records_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('records main shows active pet calendar and record type cards', (
    tester,
  ) async {
    await _pumpRecordsScreen(tester);

    expect(find.text('몽실이의 반려기록'), findsOneWidget);
    expect(find.byKey(const Key('all-record-row-meal-today')), findsNothing);
    expect(find.byKey(const Key('records-calendar')), findsOneWidget);
    expect(find.byKey(const Key('records-selected-date')), findsOneWidget);
    expect(find.byKey(const Key('records-type-card-expense')), findsNothing);
    expect(find.byKey(Key('records-date-dot-$todayIso')), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.byType(AppInlineHeader), findsOneWidget);

    for (final typeId in _recordTypeIds) {
      expect(find.byKey(Key('records-type-card-$typeId')), findsOneWidget);
    }
    expect(find.byKey(const Key('records-type-card-expense')), findsNothing);
    for (final label in _recordTypeLabels) {
      expect(find.text(label), findsWidgets);
    }

    expect(find.byKey(const Key('records-type-card-diary')), findsOneWidget);
  });

  testWidgets('records empty state keeps header and hides all records action', (
    tester,
  ) async {
    await _pumpRecordsScreen(tester, state: _state(activePetId: null));

    expect(find.byType(AppInlineHeader), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.text('반려기록'), findsOneWidget);
    expect(find.text('전체 기록'), findsNothing);
    expect(find.text('반려동물을 등록해 주세요.'), findsOneWidget);
  });

  testWidgets('record type grid does not overflow on narrow screens', (
    tester,
  ) async {
    await _pumpRecordsScreen(
      tester,
      physicalSize: const Size(320, 900),
      textScaler: TextScaler.linear(1.3),
    );

    for (final typeId in _recordTypeIds) {
      expect(find.byKey(Key('records-type-card-$typeId')), findsOneWidget);
    }
    expect(find.byKey(const Key('records-type-card-expense')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal record type opens full screen meal record form', (
    tester,
  ) async {
    await _pumpRouter(tester, initialLocation: '/records');

    await tester.tap(find.byKey(const Key('records-type-card-meal')));
    await tester.pumpAndSettle();

    expect(find.text('급식 기록'), findsOneWidget);
    expect(find.text('등록'), findsOneWidget);
  });

  testWidgets('selected calendar date is passed to record forms', (
    tester,
  ) async {
    await _pumpRouter(tester, initialLocation: '/records');

    await tester.tap(find.byKey(Key('records-calendar-day-$yesterdayIso')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('records-type-card-meal')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-date-label')), findsOneWidget);
    expect(find.text(yesterdayIso), findsOneWidget);
  });

  testWidgets('water and diary record types open their category forms', (
    tester,
  ) async {
    await _pumpRouter(tester, initialLocation: '/records');

    await tester.tap(find.byKey(const Key('records-type-card-water')));
    await tester.pumpAndSettle();

    expect(find.text('음수 기록'), findsOneWidget);
    expect(find.text('음수량'), findsOneWidget);

    await _pumpRouter(tester, initialLocation: '/records');
    await tester.tap(find.byKey(const Key('records-type-card-diary')));
    await tester.pumpAndSettle();

    expect(find.text('일기 기록'), findsOneWidget);
    expect(find.byKey(const Key('category-diary-note-field')), findsWidgets);
  });

  testWidgets('etc record type opens its category form', (tester) async {
    await _pumpRouter(tester, initialLocation: '/records');

    await tester.tap(find.byKey(const Key('records-type-card-etc')));
    await tester.pumpAndSettle();

    expect(find.text('기타 기록'), findsOneWidget);
    expect(find.byKey(const Key('category-etc-note-field')), findsOneWidget);
    expect(find.text('준비중'), findsNothing);
  });

  testWidgets('implemented record types open their category forms', (
    tester,
  ) async {
    for (final entry in {
      'poop': '배변 기록',
      'walk': '산책 기록',
      'weight': '몸무게 기록',
      'vet': '병원 기록',
      'medicine': '영양/약 기록',
      'water': '음수 기록',
      'diary': '일기 기록',
      'etc': '기타 기록',
    }.entries) {
      await _pumpRouter(tester, initialLocation: '/records');

      await tester.tap(find.byKey(Key('records-type-card-${entry.key}')));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('준비중'), findsNothing);
    }
  });

  testWidgets('records main filters selected date summary in time order', (
    tester,
  ) async {
    await _pumpRecordsScreen(tester);
    await tester.tap(find.byKey(Key('records-calendar-day-$todayIso')));
    await tester.pumpAndSettle();

    final mealRow = find.byKey(const Key('selected-date-record-meal-today'));
    final walkRow = find.byKey(const Key('selected-date-record-walk-today'));

    expect(mealRow, findsOneWidget);
    expect(walkRow, findsOneWidget);
    expect(
      find.descendant(of: mealRow, matching: find.text('09:10')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mealRow, matching: find.text('09:10:32')),
      findsNothing,
    );
    expect(
      find.descendant(of: mealRow, matching: find.text('간식')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mealRow,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('간식'), findsOneWidget);
    expect(find.text('1.2km'), findsOneWidget);
    expect(find.text('오전 간식'), findsNothing);
    expect(find.text('저녁 산책'), findsNothing);
    expect(find.text('지출 기록'), findsNothing);
    expect(find.text('전날 체중'), findsNothing);

    await tester.tap(find.byKey(Key('records-calendar-day-$yesterdayIso')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('selected-date-record-meal-today')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('selected-date-record-walk-today')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('selected-date-record-weight-yesterday')),
      findsOneWidget,
    );
    expect(find.text('오전 간식'), findsNothing);
    expect(find.text('저녁 산책'), findsNothing);
    expect(find.text('4.1kg'), findsOneWidget);
  });

  testWidgets('records main opens detail when selected date row is tapped', (
    tester,
  ) async {
    await _pumpRouter(tester, initialLocation: '/records');

    await tester.tap(find.byKey(const Key('selected-date-record-meal-today')));
    await tester.pumpAndSettle();

    expect(find.text('급식 상세'), findsOneWidget);
    expect(find.byKey(const Key('record-detail-edit-button')), findsOneWidget);
    expect(find.text('09:10'), findsOneWidget);
  });

  testWidgets('records main hides expense-only dates from list and dots', (
    tester,
  ) async {
    final expenseOnlyDate = DateTime(todayDate.year, todayDate.month, 15);
    final expenseOnlyIso = _isoDate(expenseOnlyDate);
    await _pumpRecordsScreen(
      tester,
      state: _state(
        records: [
          ActivityRecord(
            id: 'expense-only',
            petId: 'pet-1',
            typeId: 'expense',
            date: expenseOnlyIso,
            time: '10:00',
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(Key('records-calendar-day-$expenseOnlyIso')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('records-date-dot-$expenseOnlyIso')), findsNothing);
    expect(
      find.byKey(const Key('selected-date-record-expense-only')),
      findsNothing,
    );
    expect(find.text('지출 기록'), findsNothing);
  });

  testWidgets('/records/all redirects to records main screen', (tester) async {
    await _pumpRouter(tester, initialLocation: '/records/all');

    expect(find.byType(RecordsScreen), findsOneWidget);
    expect(find.byKey(const Key('records-calendar')), findsOneWidget);
    expect(find.byKey(const Key('all-record-row-meal-today')), findsNothing);
    expect(find.byKey(const Key('all-record-row-meal-today')), findsNothing);
  });

  testWidgets(
    'growth route shows weight chart and recent records newest first',
    (tester) async {
      await _pumpRouter(tester, initialLocation: '/records/growth');

      expect(find.byType(AppBackButton), findsOneWidget);
      expect(find.text('성장곡선'), findsOneWidget);
      expect(find.byKey(const Key('records-growth-chart')), findsOneWidget);
      final latest = find.text('4.5kg');
      final previous = find.text('4.1kg');
      expect(latest, findsOneWidget);
      expect(previous, findsOneWidget);
      expect(
        tester.getTopLeft(latest).dy,
        lessThan(tester.getTopLeft(previous).dy),
      );
    },
  );

  testWidgets('legacy growth query redirects to growth route', (tester) async {
    await _pumpRouter(tester, initialLocation: '/records?tab=growth');

    expect(find.text('성장곡선'), findsOneWidget);
    expect(find.byKey(const Key('records-growth-chart')), findsOneWidget);
  });
}

const _recordTypeLabels = [
  '급식',
  '음수',
  '배변',
  '산책',
  '영양',
  '병원',
  '몸무게',
  '일기',
  '기타',
];

const _recordTypeIds = [
  'meal',
  'water',
  'poop',
  'walk',
  'medicine',
  'vet',
  'weight',
  'diary',
  'etc',
];

final todayDate = DateTime.now();
final yesterdayDate = todayDate.subtract(const Duration(days: 1));
final todayIso = _isoDate(todayDate);
final yesterdayIso = _isoDate(yesterdayDate);
final todayLabel = '${todayDate.month}월 ${todayDate.day}일';
final yesterdayLabel = '${yesterdayDate.month}월 ${yesterdayDate.day}일';

Future<void> _pumpRecordsScreen(
  WidgetTester tester, {
  Size physicalSize = const Size(800, 2200),
  TextScaler? textScaler,
  PetState? state,
}) async {
  _setScreen(tester, physicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => PetNotifier.test(state ?? _state())),
      ],
      child: MaterialApp(
        builder: textScaler == null
            ? null
            : (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(textScaler: textScaler),
                  child: child!,
                );
              },
        home: const RecordsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  _setLargeScreen(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthNotifier.test(
            const AuthState(isLoading: false, isAuthenticated: true),
          ),
        ),
        petProvider.overrideWith((ref) => PetNotifier.test(_state())),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          final router = ref.watch(routerProvider);
          if (router.routeInformationProvider.value.uri.toString() !=
              initialLocation) {
            router.go(initialLocation);
          }
          return MaterialApp.router(routerConfig: router);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setLargeScreen(WidgetTester tester) {
  _setScreen(tester, const Size(800, 2200));
}

void _setScreen(WidgetTester tester, Size physicalSize) {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

PetState _state({
  String? activePetId = 'pet-1',
  List<ActivityRecord>? records,
}) => PetState(
  isLoading: false,
  hasOnboarded: activePetId != null,
  pets: const [
    Pet(
      id: 'pet-1',
      name: '몽실이',
      species: 'dog',
      birthDate: '2022-03-15',
      accentColor: '#F4A460',
      bgLight: '#FFF8F0',
    ),
  ],
  activePetId: activePetId,
  records: records ?? _records(),
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

List<ActivityRecord> _records() => [
  ActivityRecord(
    id: 'meal-today',
    petId: 'pet-1',
    typeId: 'meal',
    date: todayIso,
    time: '09:10:32',
    note: '오전 간식',
    detail: {'foodType': 'snack'},
  ),
  ActivityRecord(
    id: 'walk-today',
    petId: 'pet-1',
    typeId: 'walk',
    date: todayIso,
    time: '18:40',
    note: '저녁 산책',
    detail: {'distance': 1.2},
  ),
  ActivityRecord(
    id: 'weight-yesterday',
    petId: 'pet-1',
    typeId: 'weight',
    date: yesterdayIso,
    time: '08:00',
    note: '전날 체중',
    detail: {'value': 4.1, 'unit': 'kg'},
  ),
  ActivityRecord(
    id: 'weight-today',
    petId: 'pet-1',
    typeId: 'weight',
    date: todayIso,
    time: '21:00',
    detail: {'value': 4.5, 'unit': 'kg'},
  ),
];

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
