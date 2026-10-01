import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/app_action_sheet.dart';
import 'package:frontend/widgets/app_ink_well.dart';
import 'package:frontend/widgets/app_picker_sheet.dart';
import 'package:frontend/widgets/main_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../support/ui_test_fonts.dart';

Finder get _focusedRings =>
    find.byWidgetPredicate((w) => w is AppFocusRing && w.focused);

Future<List<int>> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List().toList();
  }))!;
}

void main() {
  testWidgets('danger sheet press is visible and cancelling never activates', (
    tester,
  ) async {
    await installUiTestFonts();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            RepaintBoundary(key: const Key('capture'), child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppActionSheet(
                context,
                title: 'Actions',
                actions: [
                  AppActionSheetItem(
                    label: 'Delete',
                    destructive: true,
                    onTap: () => calls++,
                  ),
                ],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(ListTile, 'Delete');
    final before = await _pixels(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(tile));
    await tester.pumpAndSettle();
    expect(await _pixels(tester), before);
    await mouse.removePointer();
    final press = await tester.startGesture(
      tester.getTopLeft(tile) + const Offset(30, 25),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    expect(await _pixels(tester), isNot(before));
    expect(
      Theme.of(tester.element(tile)).splashColor,
      const Color(0xFFBA1A1A).withValues(alpha: .10),
    );
    await press.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(await _pixels(tester), before);
  });

  testWidgets('action sheet Tab shows one ring and Enter dismisses once', (
    tester,
  ) async {
    await installUiTestFonts();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppActionSheet(
                context,
                title: 'Actions',
                actions: [
                  AppActionSheetItem(
                    label: 'Delete',
                    destructive: true,
                    onTap: () => calls++,
                  ),
                ],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.widgetWithText(ListTile, 'Delete'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_focusedRings, findsOneWidget);
    expect(tester.getSize(find.widgetWithText(ListTile, 'Delete')), size);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Actions'), findsNothing);
  });

  testWidgets('picker hover stays white and keyboard selection returns value', (
    tester,
  ) async {
    await installUiTestFonts();
    int? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                value = await showAppPickerSheet<int>(
                  context,
                  title: 'Pick',
                  options: const [AppSelectOption(value: 7, label: 'Seven')],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
        builder: (context, child) =>
            RepaintBoundary(key: const Key('capture'), child: child!),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final before = await _pixels(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Seven')));
    await tester.pumpAndSettle();
    expect(await _pixels(tester), before);
    await mouse.removePointer();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // close
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // option
    await tester.pumpAndSettle();
    expect(_focusedRings, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, 7);
  });

  testWidgets('multi picker Tab and Space change only the focused option', (
    tester,
  ) async {
    await installUiTestFonts();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppMultiPickerSheet<int>(
            title: 'Pick',
            searchable: false,
            selectedValues: {2},
            options: [
              AppSelectOption(value: 1, label: 'One'),
              AppSelectOption(value: 2, label: 'Two'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pumpAndSettle();
    expect(_focusedRings, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'One'),
          )
          .value,
      true,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Two'),
          )
          .value,
      true,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'One'),
          )
          .value,
      true,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Two'),
          )
          .value,
      false,
    );
  });

  testWidgets('picker search fills white while accepting and filtering text', (
    tester,
  ) async {
    await installUiTestFonts();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPickerSheet<int>(
            title: 'Pick',
            searchable: true,
            options: [AppSelectOption(value: 1, label: 'One')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      WidgetStateProperty.resolveAs(field.decoration!.fillColor!, {}),
      Colors.white,
    );
    expect(
      WidgetStateProperty.resolveAs(field.decoration!.fillColor!, {
        WidgetState.disabled,
      }),
      const Color(0xFFF5F6F5),
    );
    await tester.enterText(find.byType(TextField), 'Missing');
    await tester.pump();
    expect(find.text('One'), findsNothing);
    expect(find.text('Missing'), findsOneWidget);
  });

  testWidgets(
    'bottom navigation keeps geometry and routes with existing Tab targets',
    (tester) async {
      await installUiTestFonts();
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          for (final path in ['/home', '/community', '/my'])
            GoRoute(
              path: path,
              builder: (context, state) =>
                  MainScaffold(child: Text('Page $path')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              RepaintBoundary(key: const Key('capture'), child: child!),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(BottomNavigationBar));
      final before = await _pixels(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('커뮤니티')));
      await tester.pumpAndSettle();
      expect(await _pixels(tester), before);
      await mouse.removePointer();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focusedRings, findsOneWidget);
      expect(await _pixels(tester), isNot(before));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focusedRings, findsOneWidget);
      expect(tester.getSize(find.byType(BottomNavigationBar)), size);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(_focusedRings, findsOneWidget);
      expect(tester.getCenter(_focusedRings).dx, lessThan(300));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Page /community'), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        1,
      );
    },
  );
}
