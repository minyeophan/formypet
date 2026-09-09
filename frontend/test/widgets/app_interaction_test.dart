import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/core/app_interaction_style.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/widgets/app_ink_well.dart';
import '../support/ui_test_fonts.dart';

Future<List<int>> _pixels(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List().toList();
    image.dispose();
    return bytes;
  }))!;
}

void main() {
  testWidgets(
    'external state controller survives disabled rebuilds and replacement',
    (tester) async {
      final first = WidgetStatesController(), second = WidgetStatesController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Future<void> show(WidgetStatesController controller, bool enabled) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppFocusIndicator(
                statesController: controller,
                child: TextButton(
                  statesController: controller,
                  onPressed: enabled ? () {} : null,
                  child: const Text('Action'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(first, false);
      await show(first, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await show(first, false);
      expect(
        tester.widget<AppFocusRing>(find.byType(AppFocusRing)).focused,
        false,
      );
      await show(second, true);
      first.update(WidgetState.hovered, true);
      await tester.pumpWidget(const SizedBox());
      second.update(WidgetState.hovered, true);
      expect(tester.takeException(), isNull);
    },
  );

  test('input access and combined interaction state priority', () {
    expect(
      AppInteractionStyle.inputFill.resolve({WidgetState.hovered}),
      Colors.white,
    );
    expect(
      AppInteractionStyle.inputFill.resolve({WidgetState.disabled}),
      AppColors.surfaceSoft,
    );
    expect(
      WidgetStateProperty.resolveAs(
        AppInteractionStyle.inputFillFor(AppInputAccess.picker),
        {},
      ),
      Colors.white,
    );
    expect(
      AppInteractionStyle.inputFillFor(AppInputAccess.readOnly),
      AppColors.surfaceSoft,
    );
    expect(
      AppInteractionStyle.inputFillFor(AppInputAccess.picker, enabled: false),
      AppColors.surfaceSoft,
    );
    final overlay = AppInteractionStyle.overlay();
    expect(overlay.resolve({WidgetState.hovered}), Colors.transparent);
    expect(overlay.resolve({WidgetState.focused}), Colors.transparent);
    expect(
      overlay.resolve({WidgetState.pressed, WidgetState.hovered}),
      AppColors.primary.withValues(alpha: .10),
    );
    expect(
      overlay.resolve({WidgetState.pressed, WidgetState.disabled}),
      Colors.transparent,
    );
  });

  testWidgets(
    'hover preserves pixels, keyboard focus changes pixels without layout shift, touch hides ring',
    (tester) async {
      final key = GlobalKey();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Material(
                  color: Colors.white,
                  child: AppInkWell(
                    focusNode: focus,
                    onTap: () {},
                    borderRadius: BorderRadius.circular(16),
                    child: const SizedBox(
                      width: 200,
                      height: 80,
                      child: Center(child: Text('Card')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(AppInkWell));
      final before = await _pixels(tester, key);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(AppInkWell)));
      await tester.pumpAndSettle();
      expect(await _pixels(tester, key), before);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, true);
      expect(tester.getSize(find.byType(AppInkWell)), size);
      expect(await _pixels(tester, key), isNot(before));
      await tester.tap(find.byType(AppInkWell));
      await tester.pumpAndSettle();
      expect(await _pixels(tester, key), before);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'nested button gets one ring and one activation, disabled skips focus',
    (tester) async {
      var parentTaps = 0, childTaps = 0;
      final parent = FocusNode(), child = FocusNode(), disabled = FocusNode();
      addTearDown(() {
        parent.dispose();
        child.dispose();
        disabled.dispose();
      });
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: Column(
                children: [
                  AppInkWell(
                    focusNode: parent,
                    onTap: () => parentTaps++,
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: AppInkWell(
                        focusNode: child,
                        onTap: () => childTaps++,
                        child: const Text('Like'),
                      ),
                    ),
                  ),
                  AppInkWell(
                    focusNode: disabled,
                    child: const Text('Disabled'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      child.requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AppFocusRing>(find.byType(AppFocusRing))
            .where((ring) => ring.focused)
            .length,
        1,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(childTaps, 1);
      expect(parentTaps, 0);
      await tester.tap(find.text('Like'));
      await tester.pumpAndSettle();
      expect(childTaps, 2);
      expect(parentTaps, 0);
      expect(disabled.canRequestFocus, false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'real theme text field white during hover and typing; disabled grey',
    (tester) async {
      await installUiTestFonts();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final key = GlobalKey();
      Future<void> pump(bool enabled) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 240,
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      decoration: const InputDecoration(hintText: 'Input'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(true);
      final before = await _pixels(tester, key);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(TextField)));
      await tester.pumpAndSettle();
      expect(await _pixels(tester, key), before);
      await tester.enterText(find.byType(TextField), 'hello world');
      expect(controller.text, 'hello world');
      await pump(false);
      final decoration = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(
        WidgetStateProperty.resolveAs(decoration.decoration.fillColor!, {
          WidgetState.disabled,
        }),
        AppColors.surfaceSoft,
      );
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'standard filled and icon buttons retain keyboard focus rings with real theme',
    (tester) async {
      await installUiTestFonts();
      final node = FocusNode();
      addTearDown(node.dispose);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      for (final icon in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Center(
                child: icon
                    ? IconButton(
                        focusNode: node,
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                      )
                    : FilledButton(
                        focusNode: node,
                        onPressed: () {},
                        child: const Text('Save'),
                      ),
              ),
            ),
          ),
        );
        node.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(find.byType(AppFocusRing), findsOneWidget);
        expect(
          tester.widget<AppFocusRing>(find.byType(AppFocusRing)).focused,
          true,
        );
        expect(
          find.descendant(
            of: find.byType(AppFocusRing),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint && widget.foregroundPainter != null,
            ),
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
