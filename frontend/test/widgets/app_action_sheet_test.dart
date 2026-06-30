import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/widgets/app_action_sheet.dart';
import 'package:frontend/widgets/app_text.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders title, actions, and close label', (tester) async {
    await _pumpSheetHost(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('더보기 메뉴'), findsOneWidget);
    expect(find.text('신고하기'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);
  });

  testWidgets('action tap closes the sheet and runs callback', (tester) async {
    var taps = 0;
    await _pumpSheetHost(tester, onTap: () => taps++);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-action')));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.text('더보기 메뉴'), findsNothing);
  });

  testWidgets('destructive action uses danger text color', (tester) async {
    await _pumpSheetHost(tester, destructive: true);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final text = tester.widget<AppText>(find.widgetWithText(AppText, '신고하기'));
    expect(text.color, AppColors.danger);
  });

  testWidgets('close tap only dismisses the sheet', (tester) async {
    var taps = 0;
    await _pumpSheetHost(tester, onTap: () => taps++);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-action-sheet-close')));
    await tester.pumpAndSettle();

    expect(taps, 0);
    expect(find.text('더보기 메뉴'), findsNothing);
  });
}

Future<void> _pumpSheetHost(
  WidgetTester tester, {
  VoidCallback? onTap,
  bool destructive = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppActionSheet(
              context,
              title: '더보기 메뉴',
              actions: [
                AppActionSheetItem(
                  key: const Key('report-action'),
                  label: '신고하기',
                  destructive: destructive,
                  onTap: onTap,
                ),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}
