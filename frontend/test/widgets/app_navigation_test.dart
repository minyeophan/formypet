import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/widgets/app_navigation.dart';

void main() {
  testWidgets('AppBackButton renders a 44px chevron button and calls back', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppBackButton(tooltip: '뒤로가기', onPressed: () => taps++),
          ),
        ),
      ),
    );

    final finder = find.byTooltip('뒤로가기');
    expect(finder, findsOneWidget);
    expect(tester.getSize(finder), const Size(44, 44));

    final icon = tester.widget<Icon>(
      find.descendant(of: finder, matching: find.byType(Icon)).first,
    );
    expect(icon.icon, Icons.chevron_left_rounded);
    expect(icon.color, AppColors.text);

    await tester.tap(finder);
    expect(taps, 1);
  });

  testWidgets('AppDisclosureChevron is display-only and styleable', (
    tester,
  ) async {
    const color = Color(0xFF123456);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppDisclosureChevron(size: 24, color: color)),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.chevron_right_rounded);
    expect(icon.size, 24);
    expect(icon.color, color);

    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });
}
