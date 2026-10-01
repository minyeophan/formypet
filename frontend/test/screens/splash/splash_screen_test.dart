import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/screens/splash/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('splash retry keeps white background and press-only overlay', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(errorText: 'retry', onRetry: () => retries++),
      ),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.backgroundColor!.resolve({}), Colors.white);
    expect(
      button.style!.overlayColor!.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(
      button.style!.overlayColor!.resolve({WidgetState.focused}),
      Colors.transparent,
    );
    expect(
      button.style!.overlayColor!.resolve({WidgetState.pressed}),
      AppColors.primary.withValues(alpha: .10),
    );
    await tester.tap(find.byType(FilledButton));
    expect(retries, 1);
  });

  testWidgets('splash uses the circular mascot and wordmark below it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF70D8C8));
    expect(find.text('포마펫'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('포마펫')).style?.color,
      AppColors.text,
    );
    final logoFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/images/brand_logo_splash.png',
    );
    expect(logoFinder, findsOneWidget);
    expect(find.bySemanticsLabel('포마펫 시작 화면 로고'), findsOneWidget);
    final logo = tester.widget<Image>(logoFinder);
    expect(logo.image, isA<AssetImage>());
    expect(
      (logo.image as AssetImage).assetName,
      'assets/images/brand_logo_splash.png',
    );
    expect(
      tester.getTopLeft(find.text('포마펫')).dy,
      greaterThan(tester.getBottomLeft(logoFinder).dy),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
