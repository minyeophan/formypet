import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/visuals/app_visual_id.dart';
import 'package:frontend/core/visuals/app_visual_spec.dart';
import 'package:frontend/widgets/app_visual.dart';

void main() {
  testWidgets('all approved icons render together at app display sizes', (
    tester,
  ) async {
    final paths =
        Directory('assets/icons')
            .listSync()
            .whereType<File>()
            .map((file) => file.path.replaceAll('\\', '/'))
            .where((path) => path.endsWith('.svg'))
            .toList()
          ..sort();
    final font = FontLoader('GalleryLabels')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf'));
    await font.load();
    final height = (paths.length / 10).ceil() * 86.0;
    await tester.binding.setSurfaceSize(Size(1000, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: const Key('gallery'),
            child: ColoredBox(
              color: Colors.white,
              child: Wrap(
                children: [
                  for (final path in paths)
                    SizedBox(
                      width: 100,
                      height: 86,
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            child: Center(
                              child: AppVisual.fromSpec(
                                id: AppVisualId.genericUnknown,
                                spec: AppVisualSpec(
                                  source: SvgAssetVisualSource.figma(
                                    path,
                                    strokeWidth: _isControl(path) ? 2 : null,
                                  ),
                                ),
                                size: _isControl(path) ? 24 : 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            path.split('/').last.replaceAll('.svg', ''),
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'GalleryLabels',
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(paths.length));
    const output = String.fromEnvironment('ICON_GALLERY_OUTPUT');
    if (output.isNotEmpty) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('gallery')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File(output);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
  });
}

bool _isControl(String path) =>
    ['common_', 'ui_', 'nav_'].any(path.split('/').last.startsWith);
