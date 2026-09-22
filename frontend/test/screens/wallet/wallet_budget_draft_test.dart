import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wallet_form_budget_sidecar_test.dart' as budget;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 375.0]) {
    testWidgets('large text budget labels fit at width=$width', (tester) async {
      await budget.pumpBudget(tester, width: width, scale: 2);
      await budget.openBudget(tester);
      for (final label in ['+1만원', '+5만원', '+10만원']) {
        final button = find.widgetWithText(OutlinedButton, label);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        final rich = find
            .descendant(of: button, matching: find.byType(RichText))
            .first;
        final paragraph = tester.renderObject<RenderParagraph>(rich);
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: paragraph.textScaler,
        )..layout();
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(painter.width),
          reason: 'The complete $label must fit without clipping or wrapping',
        );
        expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
        painter.dispose();
      }
      final label = find.text('이번 달 지출');
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      final amount = find.text('7,000원');
      expect(
        tester.getTopLeft(amount).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(label).dy),
      );
      expect(
        find.ancestor(of: amount, matching: find.byType(FittedBox)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'system back protects budget and account reset clears dirty state',
    (tester) async {
      final (_, auth) = await budget.pumpBudget(tester);
      await budget.openBudget(tester);
      await tester.enterText(
        find.byKey(const Key('wallet-budget-input')),
        '50000',
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('계속 입력'));
      await tester.pumpAndSettle();
      auth.signIn('bob');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AppFormHeader), findsNothing);
    },
  );
  testWidgets('budget draft asks before leaving', (tester) async {
    await budget.pumpBudget(tester);
    await budget.openBudget(tester);
    await tester.enterText(
      find.byKey(const Key('wallet-budget-input')),
      '50000',
    );
    tester.widget<AppFormHeader>(find.byType(AppFormHeader)).onBack();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('계속 입력'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('wallet-budget-input')))
          .controller!
          .text,
      '50,000원',
    );
    tester.widget<AppFormHeader>(find.byType(AppFormHeader)).onBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-budget-input')), findsNothing);
  });
  testWidgets('budget form is centered and bounded at desktop width', (
    tester,
  ) async {
    await budget.pumpBudget(tester, width: 1024);
    await budget.openBudget(tester);
    final button = tester.getRect(find.byKey(const Key('wallet-budget-save')));
    expect(button.width, lessThanOrEqualTo(600));
    expect(button.center.dx, closeTo(512, 1));
  });
}
