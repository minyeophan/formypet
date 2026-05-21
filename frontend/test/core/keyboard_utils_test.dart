import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/keyboard_utils.dart';

void main() {
  testWidgets('dismissKeyboardBeforeTransition clears current text focus', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);

    final dismissFuture = dismissKeyboardBeforeTransition(capturedContext);
    await tester.pump();
    await dismissFuture;

    expect(focusNode.hasFocus, isFalse);
    controller.dispose();
    focusNode.dispose();
  });
}
