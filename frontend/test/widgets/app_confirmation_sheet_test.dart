import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/widgets/app_confirmation_sheet.dart';

void main() {
  testWidgets(
    'record deletion confirmation matches the designed bottom sheet',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAppConfirmationSheet(
                    context,
                    title: '기록을 삭제할까요?',
                    message: '삭제한 기록은 다시 되돌릴 수 없어요.',
                    confirmLabel: '기록 삭제',
                    confirmKey: const Key('delete-confirm'),
                    cancelKey: const Key('delete-cancel'),
                  );
                },
                child: const Text('open confirmation'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open confirmation'));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.top, closeTo(602, 1));
      expect(sheet.bottom, 844);
      expect(tester.getRect(find.text('기록을 삭제할까요?')).top, closeTo(654, 1));
      expect(
        tester.getRect(find.byKey(const Key('delete-confirm'))).top,
        closeTo(712, 1),
      );
      expect(
        tester.getRect(find.byKey(const Key('delete-cancel'))).top,
        closeTo(776, 1),
      );
      expect(
        tester.getSize(find.byKey(const Key('delete-confirm'))).height,
        52,
      );
      expect(tester.getSize(find.byKey(const Key('delete-cancel'))).height, 48);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('delete-confirm')))
            .style
            ?.backgroundColor
            ?.resolve({}),
        AppColors.danger,
      );

      await tester.tap(find.byKey(const Key('delete-cancel')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );
}
