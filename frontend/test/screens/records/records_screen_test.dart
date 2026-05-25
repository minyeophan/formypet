import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/records/records_screen.dart';
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
    expect(find.text('전체 기록'), findsOneWidget);
    expect(find.byKey(const Key('records-calendar')), findsOneWidget);
    expect(find.byKey(const Key('records-selected-date')), findsOneWidget);
    expect(find.byKey(const Key('records-date-dot-$todayIso')), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);

    for (final typeId in _recordTypeIds) {
      expect(find.byKey(Key('records-type-card-$typeId')), findsOneWidget);
    }
    for (final label in _recordTypeLabels) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.byKey(const Key('records-type-card-bath')));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);
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

  testWidgets('implemented record types open their category forms', (
    tester,
  ) async {
    for (final entry in {
      'poop': '배변 기록',
      'walk': '산책 기록',
      'weight': '몸무게 기록',
      'vet': '병원 기록',
      'medicine': '영양/약 기록',
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

    expect(find.text('오전 간식'), findsOneWidget);
    expect(find.text('저녁 산책'), findsOneWidget);
    expect(find.text('전날 체중'), findsNothing);

    await tester.tap(find.byKey(Key('records-calendar-day-$yesterdayIso')));
    await tester.pumpAndSettle();

    expect(find.text('오전 간식'), findsNothing);
    expect(find.text('저녁 산책'), findsNothing);
    expect(find.text('전날 체중'), findsOneWidget);
  });

  testWidgets('records main links all record actions to /records/all', (
    tester,
  ) async {
    await _pumpRouter(tester, initialLocation: '/records');

    await tester.tap(find.text('전체 기록'));
    await tester.pumpAndSettle();

    expect(find.text('전체 기록'), findsOneWidget);
    expect(find.text('5월 21일'), findsOneWidget);
    expect(find.text('오전 간식'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 자세히보기'));
    await tester.pumpAndSettle();

    expect(find.text('전체 기록'), findsOneWidget);
    expect(find.text('전날 체중'), findsOneWidget);
  });

  testWidgets('all records groups every record by latest date first', (
    tester,
  ) async {
    await _pumpRouter(tester, initialLocation: '/records/all');

    expect(find.byType(AppBackButton), findsOneWidget);
    final todayHeader = find.text('5월 21일');
    final yesterdayHeader = find.text('5월 20일');

    expect(todayHeader, findsOneWidget);
    expect(yesterdayHeader, findsOneWidget);
    expect(
      tester.getTopLeft(todayHeader).dy,
      lessThan(tester.getTopLeft(yesterdayHeader).dy),
    );
    expect(find.text('09:10'), findsOneWidget);
    expect(find.text('급식'), findsOneWidget);
    expect(find.text('오전 간식'), findsOneWidget);
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
  '배변',
  '산책',
  '영양/약',
  '목욕',
  '몸무게',
  '병원',
  '접종',
  '미용',
  '지출',
  '일기',
  '기타',
];

const _recordTypeIds = [
  'meal',
  'poop',
  'walk',
  'medicine',
  'bath',
  'weight',
  'vet',
  'checkup',
  'groom',
  'expense',
  'diary',
  'etc',
];

const todayIso = '2026-05-21';
const yesterdayIso = '2026-05-20';

Future<void> _pumpRecordsScreen(
  WidgetTester tester, {
  Size physicalSize = const Size(800, 2200),
  TextScaler? textScaler,
}) async {
  _setScreen(tester, physicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => PetNotifier.test(_state())),
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

PetState _state() => PetState(
  isLoading: false,
  hasOnboarded: true,
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
  activePetId: 'pet-1',
  records: _records(),
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);

List<ActivityRecord> _records() => [
  const ActivityRecord(
    id: 'meal-today',
    petId: 'pet-1',
    typeId: 'meal',
    date: '2026-05-21',
    time: '09:10',
    note: '오전 간식',
  ),
  const ActivityRecord(
    id: 'walk-today',
    petId: 'pet-1',
    typeId: 'walk',
    date: '2026-05-21',
    time: '18:40',
    note: '저녁 산책',
  ),
  const ActivityRecord(
    id: 'weight-yesterday',
    petId: 'pet-1',
    typeId: 'weight',
    date: '2026-05-20',
    time: '08:00',
    note: '전날 체중',
    detail: {'value': 4.1, 'unit': 'kg'},
  ),
  const ActivityRecord(
    id: 'weight-today',
    petId: 'pet-1',
    typeId: 'weight',
    date: '2026-05-21',
    time: '21:00',
    detail: {'value': 4.5, 'unit': 'kg'},
  ),
];
