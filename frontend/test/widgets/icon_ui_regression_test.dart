import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/screens/community/write_screen.dart';
import 'package:frontend/widgets/app_header.dart';
import 'package:frontend/widgets/app_icon.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('writing stays unboxed under the actual application theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(540, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildAppTheme(), home: const WriteScreen()),
      ),
    );
    await tester.pumpAndSettle();
    for (final key in ['community-title-field', 'community-content-field']) {
      final finder = find.byKey(Key(key));
      final field = tester.widget<TextField>(finder);
      expect(field.decoration!.filled, false);
      expect(field.decoration!.enabledBorder, InputBorder.none);
      expect(field.decoration!.focusedBorder, InputBorder.none);
      await tester.enterText(finder, '입력 확인');
      expect(field.controller!.text, '입력 확인');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('search press uses the shared green and keeps its tap action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AppHeaderIconButton(
            icon: Icons.search_rounded,
            tooltip: '검색',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppHeaderIconButton)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<AppIcon>(find.byType(AppIcon)).color,
      AppColors.primary,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
