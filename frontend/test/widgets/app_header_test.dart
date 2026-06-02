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

  testWidgets('AppHeaderIconButton supports a disabled shared icon surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppHeaderIconButton(
              key: Key('disabled-header-action'),
              icon: Icons.notifications_none_rounded,
              tooltip: '알림',
              onTap: null,
            ),
          ),
        ),
      ),
    );

    final finder = find.byKey(const Key('disabled-header-action'));
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

  test('AppHeader requires an onBack callback when back is visible', () {
    expect(
      () => AppHeader(title: '상세', showBackButton: true),
      throwsAssertionError,
    );
  });

  testWidgets('AppHeader can center its title when requested', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: AppHeader(title: '루틴 추가', centerTitle: true)),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isTrue);
  });

  testWidgets('AppInlineHeader uses symmetric 84px side slots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInlineHeader(
            title: '전체 기록',
            onBack: () {},
            trailing: const Text('액션'),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('app-inline-header-leading-slot'))),
      const Size(84, 52),
    );
    expect(
      tester.getSize(find.byKey(const Key('app-inline-header-trailing-slot'))),
      const Size(84, 52),
    );
  });

  testWidgets('AppFormHeader uses symmetric 96px side slots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFormHeader(
            title: '급식 기록',
            onBack: () {},
            trailing: const Text('등록'),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const Key('app-form-header-leading-slot')))
          .width,
      96,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('app-form-header-trailing-slot')))
          .width,
      96,
    );
    expect(tester.getSize(find.byType(AppFormHeader)).height, 56);
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
