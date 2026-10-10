import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/pet_log/pet_log_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('example detail clearly separates sample from a real record', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PetLogExampleDetailScreen(petId: '1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('예시 화면입니다'), findsOneWidget);
    expect(find.text('내 기록 남기기'), findsOneWidget);
    expect(find.text('예시 기록 삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
