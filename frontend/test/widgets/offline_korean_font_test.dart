import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/widgets/app_text.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'Korean labels use a loadable bundled font without runtime fetching',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.runAsync(() async {
        final manifest =
            jsonDecode(await rootBundle.loadString('FontManifest.json'))
                as List<dynamic>;
        final font = manifest.cast<Map<String, dynamic>>().where(
          (item) => item['family'] == 'NotoSansKR',
        );
        expect(
          font,
          hasLength(1),
          reason:
              'The Korean font must ship in the APK for first offline launch.',
        );
        final assets = (font.single['fonts'] as List)
            .cast<Map<String, dynamic>>();
        final loader = FontLoader('NotoSansKR');
        for (final path
            in assets.map((entry) => entry['asset'] as String).toSet()) {
          loader.addFont(rootBundle.load(path));
        }
        await loader.load();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: AppText('반려동물 기록 저장', fontWeight: FontWeight.bold),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('반려동물 기록 저장')).style?.fontFamily,
        'NotoSansKR',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
