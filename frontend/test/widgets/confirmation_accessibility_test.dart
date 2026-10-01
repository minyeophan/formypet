import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/screens/pet/pet_confirm_dialog.dart';
import 'package:frontend/screens/my/my_settings_screen.dart';
import 'package:frontend/widgets/record_inputs/record_edit_action_bar.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in [320.0, 375.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('confirmation actions fit ${width}px at ${scale}x', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 640);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => PetConfirmDialog(
                      title: '입력을 그만할까요?',
                      body: '저장하지 않은 내용은 사라져요. 계속 입력하려면 계속 입력을 선택해 주세요.',
                      actions: [
                        PetConfirmDialogAction(
                          label: '계속 입력',
                          onPressed: () => Navigator.pop(context),
                        ),
                        PetConfirmDialogAction(
                          label: '나가기',
                          isDanger: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['계속 입력', '나가기']) {
          final button = find.widgetWithText(TextButton, label);
          await tester.ensureVisible(button);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        }
        expect(
          tester
              .getSize(
                find.descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(SingleChildScrollView),
                ),
              )
              .width,
          lessThanOrEqualTo(480),
        );
      });
    }
  }

  testWidgets(
    'long destructive confirmation remains scrollable on short display',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDeleteConfirmationSheet(
                  context,
                  title: '기록을 삭제할까요?',
                  message:
                      '선택한 기록을 삭제해요. 삭제한 기록은 다시 되돌릴 수 없어요. 내용을 확인한 뒤 삭제해 주세요.',
                  confirmLabel: '기록 삭제',
                  confirmKey: const Key('delete'),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('취소'));
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete')), findsNothing);
    },
  );

  testWidgets('logout confirmation fits short large-text display', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLogoutConfirmationSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('취소'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsNothing);
  });
}
