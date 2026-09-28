import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/auth/policy_consent_dialog.dart';

void main() {
  testWidgets(
    'required acceptance starts unchecked and needs both affirmative actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolicyConsentDialog(
              terms: const {
                'title': '약관',
                'version': 'v1',
                'effectiveAt': '2026-09-28',
                'body': '약관 전문',
              },
              privacy: const {
                'title': '처리방침',
                'version': 'v1',
                'effectiveAt': '2026-09-28',
                'body': '처리방침 전문',
              },
            ),
          ),
        ),
      );
      final submit = find.widgetWithText(FilledButton, '동의하고 계속');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(find.text('[필수] 이용약관에 동의합니다'));
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(find.text('[필수] 만 14세 이상입니다'));
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(find.textContaining('마케팅'), findsNothing);
    },
  );
}
