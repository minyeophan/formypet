import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/app_success_toast.dart';

void main() {
  testWidgets('success toast is compact, centered, and transient', (
    tester,
  ) async {
    late BuildContext toastContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            toastContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    showAppSuccessToast(toastContext, '저장했어요.');
    await tester.pump();

    final toast = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(toast.behavior, SnackBarBehavior.floating);
    expect(toast.width, 112);
    expect(toast.duration, const Duration(milliseconds: 1600));
    expect(find.text('저장했어요.'), findsOneWidget);
  });

  testWidgets('success toast grows without truncating at large text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    late BuildContext toastContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            toastContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    const message = '차단 해제 완료';
    showAppSuccessToast(toastContext, message);
    await tester.pump();
    final text = tester.widget<Text>(find.text(message));
    expect(text.maxLines, isNull);
    final toast = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(toast.width, greaterThan(112));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
