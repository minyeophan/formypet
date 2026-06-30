import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/core/date_utils.dart';
import 'package:frontend/core/visuals/app_visual_id.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/routine.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../support/app_visual_finder.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('home shows pet cards, menu, today care, and health summary', (
    tester,
  ) async {
    final notifier = _HomeTestPetNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('petyilgi'), findsOneWidget);
    expect(find.byKey(const Key('home-notification-button')), findsOneWidget);
    expect(find.byType(AppHeaderIconButton), findsOneWidget);
    _expectDisabledHeaderActionSurface(tester, 'home-notification-button');
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFF8F9FA));
    expect(find.text('몽실이'), findsWidgets);
    expect(find.text('푸들'), findsOneWidget);
    expect(find.text('강아지'), findsOneWidget);
    expect(find.text(_ageLabelForTest('2022-03-15')), findsOneWidget);
    expect(find.text(_daysTogetherLabelForTest('2023-04-01')), findsOneWidget);
    expect(
      find.descendant(of: _homeProfileCards(), matching: find.text('4.2kg')),
      findsNothing,
    );
    expect(
      find.descendant(of: _homeProfileCards(), matching: find.text('여아')),
      findsNothing,
    );
    expect(
      find.descendant(of: _homeProfileCards(), matching: find.text('질병 기관지염')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _homeProfileCards(),
        matching: find.text('특이 닭고기 알러지'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: _homeProfileCards(), matching: find.text('건강 양호')),
      findsNothing,
    );
    expect(findAppVisual(AppVisualId.petDog), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'PetSelector',
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('home-pet-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('home-pet-dot-1')), findsOneWidget);
    expect(find.text('반려기록'), findsOneWidget);
    expect(find.text('지갑'), findsOneWidget);
    expect(find.text('루틴'), findsOneWidget);
    expect(find.text('일정'), findsNothing);
    expect(find.text('성장'), findsNothing);
    expect(find.text('반려로그'), findsOneWidget);
    expect(findAppVisual(AppVisualId.homeWallet), findsOneWidget);
    expect(findAppVisual(AppVisualId.homePetLog), findsOneWidget);
    expect(find.text('+'), findsNothing);
    expect(find.byKey(const Key('home-growth-button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-growth-button')),
        matching: find.byIcon(Icons.show_chart_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-menu-panel')), findsOneWidget);
    expect(AppColors.background, const Color(0xFFF8F9FA));
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.surfaceSoft, const Color(0xFFF3F4F6));
    expect(AppColors.border, const Color(0xFFE5E7EB));
    expect(
      _containerColor(find.byKey(const Key('home-menu-panel'))),
      AppColors.surface,
    );
    expect(
      _descendantContainerColor('_PetProfileCard', AppColors.surface),
      AppColors.surface,
    );
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(notifier.activePetChanges, ['2']);
    expect(find.text('나비'), findsWidgets);
    expect(find.text('품종 미상'), findsOneWidget);
    expect(findAppVisual(AppVisualId.petCat), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('home-menu-pet-log')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-menu-pet-log')));
    await tester.pump();
    expect(find.text('준비중'), findsOneWidget);
  });

  testWidgets('home bottom cards summarize today routines and recent health', (
    tester,
  ) async {
    final notifier = _HomeTestPetNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('오늘 관리'), findsOneWidget);
    expect(find.text('사료 주기 · 오늘 2회 예정'), findsOneWidget);
    expect(find.text('산책 · 오늘 1회 예정'), findsOneWidget);
    expect(find.text('오늘 타임라인'), findsOneWidget);
    expect(find.text('08:00 예정'), findsOneWidget);
    expect(find.text('10:30 기록됨'), findsOneWidget);
    expect(find.text('최근 건강 상태'), findsOneWidget);
    expect(find.text('최신 체중'), findsOneWidget);
    expect(find.text('4.4kg'), findsOneWidget);
    expect(find.text('최신 배변'), findsOneWidget);
    expect(find.text('보통'), findsOneWidget);
    expect(find.text('오늘 급식'), findsOneWidget);
    expect(find.text('기록됨'), findsWidgets);
    expect(find.byKey(const Key('home-bottom-spacer')), findsOneWidget);
    expect(
      _descendantContainerColor('_HomeSectionCard', AppColors.surface),
      AppColors.surface,
    );
    expect(
      _descendantContainerColor('_HealthMetricRow', AppColors.surfaceSoft),
      AppColors.surfaceSoft,
    );
  });

  testWidgets('home health summary shows empty state with insufficient data', (
    tester,
  ) async {
    final notifier = _HomeTestPetNotifier(records: const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('아직 기록이 부족해요'), findsOneWidget);
    expect(find.text('체중, 배변, 급식 기록을 남기면 최근 상태를 보여드릴게요.'), findsOneWidget);
  });

  testWidgets('home profile card falls back missing profile facts to dashes', (
    tester,
  ) async {
    final notifier = _HomeTestPetNotifier(
      pets: const [
        Pet(
          id: '1',
          name: '이름이 아주 긴 반려동물 친구',
          species: 'dog',
          birthDate: null,
          accentColor: '#F4A460',
          bgLight: '#FFF8F0',
          weight: 4.2,
          diseases: '기관지염',
          specialNotes: '닭고기 알러지',
        ),
      ],
      records: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    final profileCard = _homeProfileCards();
    expect(
      find.descendant(of: profileCard, matching: find.text('이름이 아주 긴 반려동물 친구')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('품종 미상')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('강아지')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('-')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('4.2kg')),
      findsNothing,
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('질병 기관지염')),
      findsNothing,
    );
    expect(
      find.descendant(of: profileCard, matching: find.text('특이 닭고기 알러지')),
      findsNothing,
    );
  });

  testWidgets('home profile card does not overflow on narrow long content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notifier = _HomeTestPetNotifier(
      pets: const [
        Pet(
          id: '1',
          name: '세상에서 이름이 가장 긴 반려동물 친구 몽실몽실',
          species: 'dog',
          birthDate: '2022-03-15',
          breed: '아주 긴 품종 이름을 가진 믹스견 친구',
          adoptionDate: '2023-04-01',
          accentColor: '#F4A460',
          bgLight: '#FFF8F0',
          weight: 12.34,
          diseases: '기관지염, 슬개골, 피부',
          specialNotes: '닭고기 알러지가 있고 긴 메모가 있습니다',
        ),
      ],
      records: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

void _expectDisabledHeaderActionSurface(WidgetTester tester, String key) {
  final finder = find.byKey(Key(key));
  expect(tester.getSize(finder), const Size(38, 38));

  final container = tester.widget<Container>(
    find.descendant(of: finder, matching: find.byType(Container)).first,
  );
  final decoration = container.decoration as BoxDecoration;
  expect(decoration.color, AppColors.surface);
  expect(decoration.border, Border.all(color: AppColors.border));

  final icon = tester.widget<Icon>(
    find.descendant(of: finder, matching: find.byType(Icon)).first,
  );
  expect(icon.size, 20);
  expect(icon.color, AppColors.textSecondary);

  final inkWell = tester.widget<InkWell>(
    find.descendant(of: finder, matching: find.byType(InkWell)),
  );
  expect(inkWell.onTap, isNull);
}

Color? _containerColor(Finder finder) {
  final container = finder.evaluate().single.widget as Container;
  final decoration = container.decoration as BoxDecoration;
  return decoration.color;
}

Color? _descendantContainerColor(String widgetType, Color expectedColor) {
  final root = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == widgetType,
  );
  final containers = find.descendant(
    of: root,
    matching: find.byType(Container),
  );
  for (final element in containers.evaluate()) {
    final widget = element.widget as Container;
    final decoration = widget.decoration;
    if (decoration is BoxDecoration && decoration.color == expectedColor) {
      return decoration.color;
    }
  }
  return null;
}

Finder _homeProfileCards() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_PetProfileCard',
  );
}

String _ageLabelForTest(String? birthDateIso) {
  final birth = DateTime.tryParse(birthDateIso ?? '');
  if (birth == null) return '-';
  final now = DateTime.now();
  var years = now.year - birth.year;
  final hasBirthdayPassed =
      now.month > birth.month ||
      (now.month == birth.month && now.day >= birth.day);
  if (!hasBirthdayPassed) {
    years -= 1;
  }
  return '${years < 0 ? 0 : years}살';
}

String _daysTogetherLabelForTest(String? adoptionDateIso) {
  final adoptionDate = DateTime.tryParse(adoptionDateIso ?? '');
  if (adoptionDate == null) return '-';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(
    adoptionDate.year,
    adoptionDate.month,
    adoptionDate.day,
  );
  final days = today.difference(target).inDays + 1;
  if (days < 1) return '-';
  return '$days일';
}

class _HomeTestPetNotifier extends PetNotifier {
  _HomeTestPetNotifier({List<Pet>? pets, List<ActivityRecord>? records})
    : super.test(
        PetState(
          isLoading: false,
          hasOnboarded: true,
          pets:
              pets ??
              const [
                Pet(
                  id: '1',
                  name: '몽실이',
                  species: 'dog',
                  birthDate: '2022-03-15',
                  breed: '푸들',
                  adoptionDate: '2023-04-01',
                  accentColor: '#F4A460',
                  bgLight: '#FFF8F0',
                  gender: 'female',
                  weight: 4.2,
                  diseases: '기관지염',
                  specialNotes: '닭고기 알러지',
                ),
                Pet(
                  id: '2',
                  name: '나비',
                  species: 'cat',
                  birthDate: '2021-01-02',
                  accentColor: '#4ECDC4',
                  bgLight: '#E0F7F5',
                ),
              ],
          activePetId: '1',
          records: records ?? _records(),
          routines: const [],
          todayRoutineItems: _todayRoutineItems(),
          routineCompletions: const {
            'feed:test-date': CompletionStatus.pending,
            'walk:test-date': CompletionStatus.completed,
          },
          quickTypeIds: const [],
        ),
      );

  final activePetChanges = <String>[];

  @override
  Future<void> setActivePet(String petId) async {
    activePetChanges.add(petId);
    state = state.copyWith(activePetId: petId);
  }
}

List<TodayRoutineItem> _todayRoutineItems() {
  return [
    TodayRoutineItem(
      routine: const Routine(
        id: 'feed',
        petId: '1',
        label: '사료 주기',
        typeId: 'meal',
        repeatType: 'daily',
        times: ['08:00', '18:00'],
        days: [],
        startDate: '2026-05-21',
        note: '사료 주기',
      ),
      completion: const RoutineCompletion(
        id: 'c-feed',
        routineId: 'feed',
        petId: '1',
        scheduledDate: 'test-date',
        status: CompletionStatus.pending,
      ),
    ),
    TodayRoutineItem(
      routine: const Routine(
        id: 'walk',
        petId: '1',
        label: '산책',
        typeId: 'walk',
        repeatType: 'daily',
        times: ['20:00'],
        days: [],
        startDate: '2026-05-21',
        note: '산책',
      ),
      completion: const RoutineCompletion(
        id: 'c-walk',
        routineId: 'walk',
        petId: '1',
        scheduledDate: 'test-date',
        status: CompletionStatus.completed,
      ),
    ),
  ];
}

List<ActivityRecord> _records() {
  final today = todayString();
  return [
    ActivityRecord(
      id: 'meal-1',
      petId: '1',
      typeId: 'meal',
      date: today,
      time: '09:00',
    ),
    const ActivityRecord(
      id: 'weight-1',
      petId: '1',
      typeId: 'weight',
      date: '2026-05-20',
      detail: {'value': 4.4, 'unit': 'kg'},
    ),
    const ActivityRecord(
      id: 'poop-1',
      petId: '1',
      typeId: 'poop',
      date: '2026-05-20',
      detail: {'consistency': '보통'},
    ),
    ActivityRecord(
      id: 'medicine-1',
      petId: '1',
      typeId: 'medicine',
      date: today,
      time: '10:30',
    ),
  ];
}
