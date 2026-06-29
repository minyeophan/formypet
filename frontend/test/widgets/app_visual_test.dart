import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/visuals/app_visual_spec.dart';
import 'package:frontend/core/visuals/app_visual_id.dart';
import 'package:frontend/widgets/app_visual.dart';

class _MemoryAssetBundle extends CachingAssetBundle {
  final Map<String, Uint8List> assets;

  _MemoryAssetBundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) {
      throw FlutterError('Missing asset: $key');
    }
    return ByteData.sublistView(bytes);
  }
}

Widget _host(Widget visual, AssetBundle bundle) {
  return DefaultAssetBundle(
    bundle: bundle,
    child: MaterialApp(
      home: Scaffold(body: Center(child: visual)),
    ),
  );
}

void main() {
  final emptyBundle = _MemoryAssetBundle(const {});

  testWidgets('renders Material source with requested size and color', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AppVisual.fromSpec(
          id: AppVisualId.genericUnknown,
          spec: AppVisualSpec(source: MaterialVisualSource(Icons.pets)),
          size: 28,
          color: Colors.blue,
        ),
        emptyBundle,
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.pets));
    expect(icon.size, 28);
    expect(icon.color, Colors.blue);
  });

  testWidgets('renders emoji without a forced square constraint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AppVisual.fromSpec(
          id: AppVisualId.genericUnknown,
          spec: AppVisualSpec(source: EmojiVisualSource('visual')),
          size: 32,
        ),
        emptyBundle,
      ),
    );

    final text = tester.widget<Text>(find.text('visual'));
    expect(text.style?.fontSize, 32);
    expect(
      find.ancestor(of: find.text('visual'), matching: find.byType(SizedBox)),
      findsNothing,
    );
  });

  testWidgets('renders valid SVG and raster assets without fallback', (
    tester,
  ) async {
    final bundle = _MemoryAssetBundle({
      'valid.svg': Uint8List.fromList(
        utf8.encode('<svg viewBox="0 0 1 1"><path d="M0 0h1v1H0z"/></svg>'),
      ),
      'valid.png': base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    });

    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            AppVisual.fromSpec(
              id: AppVisualId.genericUnknown,
              spec: AppVisualSpec(
                source: SvgAssetVisualSource('valid.svg'),
                fallback: AppVisualFallback.material(Icons.error),
              ),
              size: 24,
            ),
            AppVisual.fromSpec(
              id: AppVisualId.genericUnknown,
              spec: AppVisualSpec(
                source: RasterAssetVisualSource('valid.png'),
                fallback: AppVisualFallback.emoji('fallback-raster'),
              ),
              size: 24,
            ),
          ],
        ),
        bundle,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.text('fallback-raster'), findsNothing);
  });

  testWidgets(
    'uses fallback for missing and corrupt assets without exception',
    (tester) async {
      final bundle = _MemoryAssetBundle({
        'broken.svg': Uint8List.fromList(utf8.encode('not svg')),
        'broken.png': Uint8List.fromList([0, 1, 2, 3]),
      });

      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              AppVisual.fromSpec(
                id: AppVisualId.genericUnknown,
                spec: AppVisualSpec(
                  source: SvgAssetVisualSource('missing.svg'),
                  fallback: AppVisualFallback.material(Icons.help),
                ),
                size: 24,
              ),
              AppVisual.fromSpec(
                id: AppVisualId.genericUnknown,
                spec: AppVisualSpec(
                  source: SvgAssetVisualSource('broken.svg'),
                  fallback: AppVisualFallback.emoji('fallback-svg'),
                ),
                size: 24,
              ),
              AppVisual.fromSpec(
                id: AppVisualId.genericUnknown,
                spec: AppVisualSpec(
                  source: RasterAssetVisualSource('broken.png'),
                  fallback: AppVisualFallback.material(
                    Icons.image_not_supported,
                  ),
                ),
                size: 24,
              ),
            ],
          ),
          bundle,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.help), findsOneWidget);
      expect(find.text('fallback-svg'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    },
  );
}
