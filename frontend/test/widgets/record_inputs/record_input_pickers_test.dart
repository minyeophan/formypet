import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/record_inputs/record_inputs.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('date sheet returns null from cancel and dismiss', (
    tester,
  ) async {
    DateTime? result;
    await _pumpSheetHost(
      tester,
      onPressed: (context) async {
        result = await showRecordDatePickerSheet(
          context,
          initialDate: DateTime(2026, 5, 23),
        );
      },
    );

    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-date-year-wheel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('record-picker-cancel')));
    await tester.pumpAndSettle();
    expect(result, isNull);

    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('date sheet returns the selected date from done', (tester) async {
    DateTime? result;
    await _pumpSheetHost(
      tester,
      onPressed: (context) async {
        result = await showRecordDatePickerSheet(
          context,
          initialDate: DateTime(2026, 5, 23),
        );
      },
    );

    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 5, 23));
  });

  testWidgets('number pad layout keeps dot left of zero and done in header', (
    tester,
  ) async {
    final controller = TextEditingController(text: '9');
    addTearDown(controller.dispose);

    await _pumpNumberInput(tester, controller: controller);
    await tester.tap(find.byKey(const Key('number-field')));
    await tester.pumpAndSettle();

    final dotCenter = tester.getCenter(
      find.byKey(const Key('record-number-key-dot')),
    );
    final zeroCenter = tester.getCenter(
      find.byKey(const Key('record-number-key-0')),
    );
    final doneCenter = tester.getCenter(
      find.byKey(const Key('record-picker-done')),
    );
    final cancelCenter = tester.getCenter(
      find.byKey(const Key('record-picker-cancel')),
    );
    final oneTop = tester
        .getTopLeft(find.byKey(const Key('record-number-key-1')))
        .dy;

    expect(dotCenter.dx, lessThan(zeroCenter.dx));
    expect((dotCenter.dy - zeroCenter.dy).abs(), lessThanOrEqualTo(1));
    expect(doneCenter.dx, greaterThan(160));
    expect((doneCenter.dy - cancelCenter.dy).abs(), lessThanOrEqualTo(4));
    expect(doneCenter.dy, lessThan(oneTop));
  });

  testWidgets('number pad cancel and dismiss keep existing controller value', (
    tester,
  ) async {
    final controller = TextEditingController(text: '9');
    addTearDown(controller.dispose);

    await _pumpNumberInput(tester, controller: controller);
    await tester.tap(find.byKey(const Key('number-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-number-key-1')));
    await tester.tap(find.byKey(const Key('record-picker-cancel')));
    await tester.pumpAndSettle();
    expect(controller.text, '9');

    await tester.tap(find.byKey(const Key('number-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-number-key-1')));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(controller.text, '9');
  });

  testWidgets('number pad done commits normalized controller value', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changed = '';

    await _pumpNumberInput(
      tester,
      controller: controller,
      onChanged: (value) => changed = value,
    );
    await tester.tap(find.byKey(const Key('number-field')));
    await tester.pumpAndSettle();
    for (final key in ['1', 'dot', '2', '3']) {
      await tester.tap(find.byKey(Key('record-number-key-$key')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('record-picker-done')));
    await tester.pumpAndSettle();

    expect(controller.text, '1.23');
    expect(changed, '1.23');
  });

  testWidgets('number pad essentials fit in a 320 by 640 viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pumpNumberInput(tester, controller: controller);
    await tester.tap(find.byKey(const Key('number-field')));
    await tester.pumpAndSettle();

    for (final key in [
      const Key('record-picker-done'),
      const Key('record-picker-cancel'),
      const Key('record-number-key-0'),
      const Key('record-number-key-backspace'),
    ]) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.bottom, lessThanOrEqualTo(640));
    }
  });
}

Future<void> _pumpSheetHost(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onPressed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const Key('open-sheet'),
            onPressed: () => onPressed(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpNumberInput(
  WidgetTester tester, {
  required TextEditingController controller,
  ValueChanged<String>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: RecordNumberInput(
              key: const Key('number-field'),
              controller: controller,
              mode: RecordNumberInputMode.decimal,
              suffixText: 'km',
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
}
