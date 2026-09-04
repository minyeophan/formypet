import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/splash/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('splash uses the mint brand background and centered wordmark', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF70D8C8));
    expect(find.text('포마펫'), findsOneWidget);
    expect(find.bySemanticsLabel('포마펫 로고'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
