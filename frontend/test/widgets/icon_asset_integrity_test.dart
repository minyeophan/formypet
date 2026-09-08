import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/visuals/app_visual_id.dart';
import 'package:frontend/core/visuals/app_visual_spec.dart';
import 'package:frontend/widgets/app_visual.dart';

const _assets = <String>[
  'common_back',
  'common_forward',
  'common_down',
  'common_search',
  'common_bell',
  'common_bell_new',
  'common_heart',
  'common_photo',
  'common_share',
  'common_comment',
  'common_report',
  'common_block',
  'common_help',
  'common_send',
  'common_settings',
  'common_edit',
  'common_delete',
  'common_add',
  'common_save',
  'common_check',
  'common_calendar',
  'ui_close',
  'ui_more',
  'ui_collapse',
  'ui_reply',
  'ui_info',
  'ui_repeat',
  'ui_camera',
  'ui_add_camera',
  'ui_image_error',
  'ui_poll',
  'ui_unchecked',
  'ui_eye',
  'ui_eye_off',
  'ui_clear',
  'ui_logout',
  'ui_group',
  'ui_profile',
  'ui_theme',
  'ui_announcement',
  'ui_support',
  'ui_heart_outline',
  'ui_done',
  'ui_top',
  'home_records',
  'home_wallet',
  'home_routine',
  'home_pet_log',
  'community_show',
  'community_question',
  'community_free',
  'ui_map',
  'record_meal',
  'record_water',
  'record_walk',
  'record_poop',
  'record_medicine',
  'record_vet',
  'record_bath',
  'record_groom',
  'record_diary',
  'record_etc',
  'record_weight',
];

Widget _visual(String name) => AppVisual.fromSpec(
  id: AppVisualId.genericUnknown,
  spec: AppVisualSpec(
    source: SvgAssetVisualSource.figma(
      'assets/icons/$name.svg',
      strokeWidth: name.startsWith('common_') || name.startsWith('ui_')
          ? 2
          : null,
    ),
  ),
  size: 48,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('review');
    loader.addFont(
      rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf'),
    );
    await loader.load();
  });
  testWidgets(
    'restored assets are centered and cannot paint outside their slot',
    (tester) async {
      final captures = <ui.Image>[];
      final output = Platform.environment['ICON_REVIEW_OUTPUT'];
      for (final name in _assets) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: const Key('capture'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _visual(name),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var left = image.width, top = image.height, right = -1, bottom = -1;
          var centerInk = 0;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (data.getUint8((y * image.width + x) * 4 + 3) < 128) continue;
              if (x < left) left = x;
              if (x > right) right = x;
              if (y < top) top = y;
              if (y > bottom) bottom = y;
              // The settings center ring must exist independently of the outer gear.
              if (x >= 64 && x < 96 && y >= 64 && y < 96) centerInk++;
            }
          }
          if (output != null) captures.add(image.clone());
          image.dispose();
          expect(right, greaterThan(left), reason: name);
          expect(left, greaterThanOrEqualTo(32), reason: name);
          expect(top, greaterThanOrEqualTo(32), reason: name);
          expect(right, lessThan(128), reason: name);
          expect(bottom, lessThan(128), reason: name);
          expect((left + right + 1) / 4, closeTo(40, 0.8), reason: name);
          expect((top + bottom + 1) / 4, closeTo(40, 0.8), reason: name);
          if (name == 'common_settings') expect(centerInk, greaterThan(30));
        });
      }
      if (output != null) {
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final height = ((_assets.length + 7) ~/ 8) * 96;
          canvas.drawColor(Colors.white, BlendMode.src);
          for (var i = 0; i < captures.length; i++) {
            final x = (i % 8) * 100.0, y = (i ~/ 8) * 96.0;
            final image = captures[i];
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(
                0,
                0,
                image.width.toDouble(),
                image.height.toDouble(),
              ),
              Rect.fromLTWH(x + 10, y, 80, 80),
              Paint(),
            );
            final paragraph =
                (ui.ParagraphBuilder(
                        ui.ParagraphStyle(
                          fontFamily: 'review',
                          fontSize: 8,
                          textAlign: TextAlign.center,
                        ),
                      )
                      ..pushStyle(ui.TextStyle(color: Colors.black))
                      ..addText(_assets[i]))
                    .build();
            paragraph.layout(const ui.ParagraphConstraints(width: 100));
            canvas.drawParagraph(paragraph, Offset(x, y + 80));
            paragraph.dispose();
          }
          final picture = recorder.endRecording();
          final sheet = await picture.toImage(800, height);
          final data = (await sheet.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(output).writeAsBytes(data.buffer.asUint8List());
          for (final image in captures) {
            image.dispose();
          }
          sheet.dispose();
          picture.dispose();
        });
      }
    },
  );
}
