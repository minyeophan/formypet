import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/visuals/app_visual_id.dart';
import 'package:frontend/core/visuals/app_visual_spec.dart';
import 'package:frontend/widgets/app_icon.dart';
import 'package:frontend/widgets/app_visual.dart';

class _SvgBundle extends CachingAssetBundle {
  final String svg;
  _SvgBundle(this.svg);

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(svg)));
}

Widget _host(Widget child, String svg) => DefaultAssetBundle(
  bundle: _SvgBundle(svg),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

Future<Rect> _inkBounds(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  return (await tester.runAsync(() async {
    const scale = 4.0;
    final image = await boundary.toImage(pixelRatio: scale);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var left = image.width;
    var top = image.height;
    var right = -1;
    var bottom = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (bytes.getUint8((y * image.width + x) * 4 + 3) < 128) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    image.dispose();
    return Rect.fromLTRB(
      left / scale,
      top / scale,
      (right + 1) / scale,
      (bottom + 1) / scale,
    );
  }))!;
}

void main() {
  const squareSvg =
      '<svg width="64" height="64" viewBox="0 0 64 64" '
      'xmlns="http://www.w3.org/2000/svg">'
      '<rect x="8" y="8" width="48" height="48" fill="#111111"/></svg>';

  testWidgets('tint preserves transparent and disabled opacity', (
    tester,
  ) async {
    for (final opacity in [0.0, 0.38, 1.0]) {
      final color = Colors.black.withValues(alpha: opacity);
      await tester.pumpWidget(
        _host(AppIcon(Icons.search_rounded, size: 24, color: color), squareSvg),
      );
      await tester.pumpAndSettle();
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = picture.bytesLoader as SvgStringLoader;
      final actual = loader.colorMapper!.substitute(
        null,
        'path',
        'stroke',
        const Color(0xff111111),
      );
      expect(actual.a, closeTo(opacity, 0.01));
    }
  });

  testWidgets('normalized strokes stay inside the icon including their edges', (
    tester,
  ) async {
    for (final size in [16.0, 24.0, 32.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const Key('capture'),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppIcon(
                    Icons.check_circle_rounded,
                    size: size,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ink = await _inkBounds(tester);
      expect(ink.left, greaterThanOrEqualTo(8), reason: 'size=$size');
      expect(ink.top, greaterThanOrEqualTo(8), reason: 'size=$size');
      expect(ink.right, lessThanOrEqualTo(8 + size), reason: 'size=$size');
      expect(ink.bottom, lessThanOrEqualTo(8 + size), reason: 'size=$size');
    }
  });

  testWidgets('visuals support intrinsic layouts used by dialogs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [AppIcon(Icons.search_rounded, size: 24)],
          ),
        ),
        squareSvg,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SvgPicture)), const Size(24, 24));
  });

  testWidgets('a large parent does not enlarge or stretch a requested visual', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 52,
          height: 64,
          child: AppVisual.fromSpec(
            id: AppVisualId.genericUnknown,
            spec: AppVisualSpec(source: SvgAssetVisualSource('fixture.svg')),
            size: 28,
          ),
        ),
        squareSvg,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SvgPicture)), const Size(28, 28));
    expect(tester.getCenter(find.byType(SvgPicture)), const Offset(400, 300));
  });

  testWidgets(
    'the 48px drawing in a Figma canvas occupies the requested size',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const RepaintBoundary(
            key: Key('capture'),
            child: AppIcon(Icons.search_rounded, size: 24, color: Colors.black),
          ),
          squareSvg,
        ),
      );
      await tester.pumpAndSettle();
      expect(await _inkBounds(tester), const Rect.fromLTWH(0, 0, 24, 24));
    },
  );

  testWidgets('common outline stays two logical pixels at compact sizes', (
    tester,
  ) async {
    for (final size in [16.0, 24.0, 32.0]) {
      await tester.pumpWidget(
        _host(
          RepaintBoundary(
            key: const Key('capture'),
            child: AppIcon(
              Icons.search_rounded,
              size: size,
              color: Colors.black,
            ),
          ),
          '<svg width="64" height="64" viewBox="0 0 64 64" '
          'xmlns="http://www.w3.org/2000/svg">'
          '<path d="M8 32H56" stroke="#111111" stroke-width="2"/></svg>',
        ),
      );
      await tester.pumpAndSettle();
      final ink = await _inkBounds(tester);
      expect(ink.height, closeTo(2, 0.25), reason: 'size=$size');
    }
  });
}
