import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/screens/wallet/expense_form.dart';

void main() {
  for (final mode in ExpenseFormMode.values) {
    testWidgets('$mode draft survives submitting and failed parent rebuilds', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late StateSetter rebuild;
      var submitting = false;
      ExpenseFormData? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return ExpenseFormBody(
                  mode: mode,
                  initialData: ExpenseFormData(
                    date: DateTime(2026, 9, 8),
                    time: const TimeOfDay(hour: 9, minute: 0),
                    amount: 12000,
                    category: 'food',
                    itemName: '',
                    note: '',
                  ),
                  petName: 'Mochi',
                  submitting: submitting,
                  errorText: null,
                  onSubmit: (data) => saved = data,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('expense-memo-field')),
        'unsaved memo',
      );
      await tester.enterText(
        find.byKey(const Key('expense-item-name-field')),
        'unsaved item',
      );
      rebuild(() => submitting = true);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (w) =>
                    w is TextField && w.key == const Key('expense-memo-field'),
              ),
            )
            .controller!
            .text,
        'unsaved memo',
      );
      rebuild(() => submitting = false);
      await tester.pump();
      await tester.tap(_saveButton());
      await tester.pumpAndSettle();
      expect(saved?.note, 'unsaved memo');
      expect(saved?.itemName, 'unsaved item');
      expect(saved?.amount, 12000);
      expect(saved?.category, 'food');
    });
  }

  testWidgets(
    'valid expense save uses primary green and the shared button geometry',
    (tester) async {
      ExpenseFormData? saved;
      await _pumpForm(tester, onSubmit: (value) => saved = value);

      expect(_saveDecoration(tester).color, AppColors.primary);
      expect(_saveDecoration(tester).borderRadius, BorderRadius.circular(20));
      expect(tester.getSize(_saveButton()).height, 52);

      await tester.tap(_saveButton());
      await tester.pumpAndSettle();
      expect(saved?.amount, 12000);
      expect(saved?.category, 'food');
    },
  );

  testWidgets('expense save shows pressed green until pointer is released', (
    tester,
  ) async {
    var saves = 0;
    await _pumpForm(tester, onSubmit: (_) => saves++);

    final pointer = await tester.startGesture(tester.getCenter(_saveButton()));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_saveDecoration(tester).color, AppColors.primaryPressed);
    expect(saves, 0);

    await pointer.up();
    await tester.pumpAndSettle();
    expect(_saveDecoration(tester).color, AppColors.primary);
    expect(saves, 1);
  });

  testWidgets(
    'invalid expense keeps disabled save appearance and ignores taps',
    (tester) async {
      var saves = 0;
      await _pumpForm(tester, amount: 0, onSubmit: (_) => saves++);

      await tester.tap(_saveButton());
      await tester.pumpAndSettle();
      expect(_saveDecoration(tester).color, AppColors.surfaceSoft);
      expect(saves, 0);
    },
  );

  testWidgets('submitting expense disables save with visible progress', (
    tester,
  ) async {
    var saves = 0;
    await _pumpForm(tester, submitting: true, onSubmit: (_) => saves++);

    await tester.tap(_saveButton());
    await tester.pump(const Duration(milliseconds: 200));
    expect(saves, 0);
    expect(_saveDecoration(tester).color, AppColors.surfaceSoft);
    final progress = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: _saveButton(),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(progress.color, AppColors.primary);
  });
}

Finder _saveButton() => find.byKey(const Key('expense-save-button'));

BoxDecoration _saveDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: _saveButton(),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

Future<void> _pumpForm(
  WidgetTester tester, {
  int amount = 12000,
  bool submitting = false,
  required ValueChanged<ExpenseFormData> onSubmit,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExpenseFormBody(
          mode: ExpenseFormMode.add,
          initialData: ExpenseFormData(
            date: DateTime(2026, 9, 8),
            time: const TimeOfDay(hour: 9, minute: 0),
            amount: amount,
            category: 'food',
            itemName: '',
            note: '',
          ),
          petName: 'Mochi',
          submitting: submitting,
          errorText: null,
          onSubmit: onSubmit,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}
