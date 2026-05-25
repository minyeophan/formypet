import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_navigation.dart';
import 'package:frontend/widgets/preparing_toast.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('AppHeaderIconButton uses the shared icon surface style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppHeader(
            title: '마이페이지',
            actions: [
              AppHeaderIconButton(
                key: const Key('shared-header-action'),
                icon: Icons.settings_outlined,
                tooltip: '설정',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final finder = find.byKey(const Key('shared-header-action'));
    expect(tester.getSize(finder), const Size(38, 38));

    final container = tester.widget<Container>(
      find.descendant(of: finder, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.surface);
    expect(decoration.borderRadius, BorderRadius.circular(14));
    expect(decoration.border, Border.all(color: AppColors.border));

    final icon = tester.widget<Icon>(
      find.descendant(of: finder, matching: find.byType(Icon)).first,
    );
    expect(icon.size, 20);
    expect(icon.color, AppColors.textSecondary);
  });

  testWidgets('AppHeader can render the shared back button', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppHeader(
            title: '상세',
            showBackButton: true,
            onBack: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byType(AppBackButton), findsOneWidget);
    expect(tester.getSize(find.byType(AppBackButton)), const Size(44, 44));

    await tester.tap(find.byType(AppBackButton));
    expect(taps, 1);
  });

  testWidgets('showPreparingToast shows the shared preparing snack bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showPreparingToast(context),
                child: const Text('show'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();

    expect(find.text('준비중'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.width, 112);
    expect(snackBar.duration, const Duration(milliseconds: 1200));
    expect(snackBar.backgroundColor, AppColors.surface);
    expect(snackBar.shape, isA<RoundedRectangleBorder>());
  });
}
