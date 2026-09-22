import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/screens/wallet/wallet_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('category has one accessible name and retains selection action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletCategorySelector(
              selected: 'food',
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('사료'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('사료')),
        matchesSemantics(
          label: '사료',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.bySemanticsLabel('간식'));
      expect(selected, 'snack');
    } finally {
      semantics.dispose();
    }
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets(
      '$kind scroll reaches last category without selecting on drag',
      (tester) async {
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: WalletCategorySelector(
                    selected: null,
                    onSelected: (value) => selected = value,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        final gesture = await tester.createGesture(kind: kind);
        await gesture.down(const Offset(280, 32));
        await gesture.moveBy(const Offset(-260, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, greaterThan(0));
        expect(selected, isNull);
        await tester.tap(find.text('용품').hitTestable());
        await tester.pumpAndSettle();
        expect(selected, 'supplies');
      },
    );
  }
}
