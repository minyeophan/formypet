import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/app_picker_sheet.dart';
import 'package:frontend/widgets/pet_log_export_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'limit sheet stays scrollable with enlarged text on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPetLogExportSheet(
                  context,
                  title: '기본 플랜은 사진을 최대 5장까지 선택할 수 있어요.',
                  description: '선택한 사진을 해제하면 다른 사진을 고를 수 있어요.',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('확인'));
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('year picker handle belongs inside its compact surface', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppPickerSheet<int>(
                context,
                title: '연도 선택',
                showDragHandle: true,
                selectedValue: 2026,
                options: const [AppSelectOption(value: 2026, label: '2026년')],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final handle = find.byKey(const Key('app-picker-drag-handle'));
    expect(handle, findsOneWidget);
    expect(
      tester.getTopLeft(handle).dy,
      greaterThan(
        tester.view.physicalSize.height / tester.view.devicePixelRatio / 2,
      ),
    );
    expect(
      tester.getBottomLeft(handle).dy,
      lessThan(tester.getTopLeft(find.text('연도 선택')).dy),
    );
    await tester.tap(find.text('2026년'));
    await tester.pumpAndSettle();
    expect(find.text('연도 선택'), findsNothing);
  });
}
