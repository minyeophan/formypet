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
}
