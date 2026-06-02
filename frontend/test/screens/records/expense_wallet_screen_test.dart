import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/activity_record.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/records/expense_report_screen.dart';
import 'package:frontend/screens/records/expense_wallet_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('wallet screen shows actions, totals, and recent expenses', (
    tester,
  ) async {
    await _pumpScreen(tester, const ExpenseWalletScreen());

    expect(find.text('집사의 지갑'), findsOneWidget);
    expect(find.text('비용 추가'), findsOneWidget);
    expect(find.text('내역 보기'), findsOneWidget);
    expect(find.text('35,000원'), findsOneWidget);
    expect(find.text('간식'), findsOneWidget);
    expect(find.text('병원 메모'), findsOneWidget);
    expect(find.textContaining('기타'), findsOneWidget);
    expect(find.text('약 연동'), findsNothing);
    expect(find.text('빠른 지출'), findsNothing);
    expect(find.text('빠르게 저장'), findsNothing);
    expect(find.byType(AppInlineHeader), findsOneWidget);
  });

  testWidgets('report screen shows period, category summary, and expenses', (
    tester,
  ) async {
    await _pumpScreen(tester, const ExpenseReportScreen());

    expect(find.text('지출 리포트'), findsOneWidget);
    expect(find.text('2026-05-20 - 2026-05-21'), findsOneWidget);
    expect(find.text('35,000원'), findsWidgets);
    expect(find.text('식비'), findsOneWidget);
    expect(find.text('15,000원'), findsWidgets);
    expect(find.text('기타'), findsWidgets);
    expect(find.text('20,000원'), findsWidgets);
    expect(find.text('약 연동'), findsNothing);
    expect(find.text('빠른 지출'), findsNothing);
    expect(find.text('빠르게 저장'), findsNothing);
    expect(find.byType(AppInlineHeader), findsOneWidget);
  });
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petProvider.overrideWith((ref) => PetNotifier.test(_state())),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
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
  records: const [
    ActivityRecord(
      id: 'expense-food',
      petId: 'pet-1',
      typeId: 'expense',
      date: '2026-05-21',
      time: '09:00',
      detail: {'itemName': '간식', 'amount': 15000, 'category': '식비'},
    ),
    ActivityRecord(
      id: 'expense-note',
      petId: 'pet-1',
      typeId: 'expense',
      date: '2026-05-20',
      time: '18:00',
      note: '병원 메모',
      detail: {'amount': 20000},
    ),
    ActivityRecord(
      id: 'meal',
      petId: 'pet-1',
      typeId: 'meal',
      date: '2026-05-21',
    ),
  ],
  routines: const [],
  todayRoutineItems: const [],
  routineCompletions: const {},
  quickTypeIds: const [],
);
