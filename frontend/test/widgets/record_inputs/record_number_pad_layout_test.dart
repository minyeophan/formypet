import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/visuals/app_visual_spec.dart';
import 'package:frontend/widgets/app_visual.dart';
import 'package:frontend/widgets/record_inputs/record_number_input.dart';
import 'package:frontend/widgets/record_inputs/record_picker_values.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('landscape number pad keeps zero, erase, and done usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showRecordNumberPadSheet(
                  context,
                  initialValue: '12',
                  mode: RecordNumberInputMode.integer,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final zero = find.byKey(const Key('record-number-key-0'));
    await tester.ensureVisible(zero);
    await tester.pumpAndSettle();
    await tester.tap(zero);
    await tester.tap(find.byKey(const Key('record-number-key-backspace')));
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();
    expect(saved, '12');
    expect(tester.takeException(), isNull);
  });

  testWidgets('number pad erase uses approved SVG artwork', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRecordNumberPadSheet(
                context,
                initialValue: '',
                mode: RecordNumberInputMode.integer,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final visuals = tester.widgetList<AppVisual>(
      find.descendant(
        of: find.byKey(const Key('record-number-key-backspace')),
        matching: find.byType(AppVisual),
      ),
    );
    expect(visuals, hasLength(1));
    expect(
      (visuals.single.spec.source as SvgAssetVisualSource).path,
      'assets/icons/ui_clear.svg',
    );
  });
}
