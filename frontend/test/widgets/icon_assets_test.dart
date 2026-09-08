import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/visuals/app_visual_catalog.dart';
import 'package:frontend/core/visuals/app_visual_spec.dart';
import 'package:frontend/widgets/app_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every shipped SVG is a single valid 64px document and decodes',
    () async {
      final files = Directory('assets/icons')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.svg'));
      expect(files.length, greaterThanOrEqualTo(92));
      for (final file in files) {
        final data = file.readAsStringSync();
        expect(RegExp(r'<svg\b').allMatches(data).length, 1, reason: file.path);
        expect(RegExp(r'</svg>').allMatches(data).length, 1, reason: file.path);
        expect(data, contains('viewBox="0 0 64 64"'), reason: file.path);
        final picture = await vg.loadPicture(SvgStringLoader(data), null);
        picture.picture.dispose();
      }
    },
  );

  test('every catalog and common icon asset is bundled', () async {
    final paths = <String>{
      ...appVisualCatalog.values.map(
        (spec) => (spec.source as SvgAssetVisualSource).path,
      ),
      ...AppIcon.assets.values,
    };
    for (final path in paths) {
      expect(await rootBundle.loadString(path), isNotEmpty, reason: path);
    }
  });

  testWidgets(
    'state tint preserves white interiors and red notification accents',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppIcon(
              Icons.notifications_active,
              size: 32,
              color: Colors.green,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final mapper = (picture.bytesLoader as SvgStringLoader).colorMapper!;
      expect(
        mapper.substitute(null, 'path', 'stroke', Colors.black).toARGB32(),
        Colors.green.toARGB32(),
      );
      expect(
        mapper.substitute(null, 'path', 'fill', Colors.white),
        Colors.white,
      );
      expect(mapper.substitute(null, 'circle', 'fill', Colors.red), Colors.red);
    },
  );
}
