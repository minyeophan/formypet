import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/pet_log/pet_log_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('example detail clearly separates sample from a real record', (
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

    expect(find.text('예시 화면입니다.'), findsOneWidget);
    expect(
      find.text(
        '사진을 올리고 그날의 이야기를 남겨보세요.\n'
        '기록이 쌓이면 날짜순으로 다시 볼 수 있어요.\n\n'
        '이 예시 기록은 원할 때 삭제할 수 있어요.',
      ),
      findsOneWidget,
    );
    expect(find.text('내 기록 남기기'), findsOneWidget);
    expect(find.text('삭제'), findsNothing);
    final photoRect = tester.getRect(find.byType(Image).first);
    expect(photoRect.width / photoRect.height, closeTo(1, 0.02));
    expect(
      find.ancestor(
        of: find.byType(Image).first,
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
    expect(find.byTooltip('예시 기록 더보기'), findsNothing);
    expect(find.text('예시 기록을 삭제할까요?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
