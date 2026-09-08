import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/records/records_screen.dart';
import 'package:frontend/screens/routine/routine_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final entry in <String, Widget>{
    'records': const RecordsScreen(),
    'routine': const RoutineScreen(),
  }.entries) {
    testWidgets('${entry.key} offers retry after pet data load failure', (
      tester,
    ) async {
      final notifier = _RetryPetNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [petProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(home: entry.value),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('데이터 조회 실패'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(notifier.retries, 1);
      expect(find.text('데이터 조회 실패'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _RetryPetNotifier extends PetNotifier {
  _RetryPetNotifier()
    : super.test(
        const PetState(
          isLoading: false,
          hasOnboarded: true,
          dataErrorText: '데이터 조회 실패',
          pets: [
            Pet(
              id: '1',
              name: '몽실',
              species: 'dog',
              birthDate: '2022-01-01',
              accentColor: '#32B982',
              bgLight: '#F5F6F5',
            ),
          ],
          activePetId: '1',
          records: [],
          routines: [],
          todayRoutineItems: [],
          routineCompletions: {},
          quickTypeIds: [],
        ),
      );
  int retries = 0;
  @override
  Future<void> retryDataLoad() async {
    retries++;
    state = state.copyWith(clearDataError: true);
  }
}
