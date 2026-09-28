import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/main.dart' as app;

void main() {
  testWidgets(
    'SDK initialization failures do not prevent public policy navigation',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      app.main();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('이용약관 · 개인정보 처리방침'));
      await tester.tap(find.text('이용약관 · 개인정보 처리방침'));
      await tester.pumpAndSettle();
      expect(find.text('약관 및 정책'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
