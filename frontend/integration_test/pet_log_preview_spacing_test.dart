import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/models/pet_log.dart';
import 'package:frontend/screens/pet_log/pet_log_export_screen.dart';
import 'package:frontend/services/pet_log_export_source.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('portrait and landscape previews keep controls beside video', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    final directory = (await getExternalStorageDirectory())!;
    expect(directory.path, contains('com.formypet.frontend.mediatest/'));
    initApiClient('https://isolated.invalid', includeAuthInterceptor: false);
    await binding.convertFlutterSurfaceToImage();
    for (final size in [const Size(240, 360), const Size(360, 240)]) {
      final fixture = img.Image(
        width: size.width.toInt(),
        height: size.height.toInt(),
      );
      img.fill(fixture, color: img.ColorRgb8(50, 185, 130));
      img.fillRect(
        fixture,
        x1: 8,
        y1: 8,
        x2: fixture.width - 9,
        y2: fixture.height - 9,
        color: img.ColorRgb8(20, 95, 75),
      );
      img.fillRect(
        fixture,
        x1: 16,
        y1: 16,
        x2: 45,
        y2: 75,
        color: img.ColorRgb8(255, 255, 255),
      );
      final bytes = Uint8List.fromList(img.encodeJpg(fixture));
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expectSync(request.method, 'GET');
            handler.resolve(Response(requestOptions: request, data: bytes));
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: PetLogExportResultScreen(
            key: ValueKey(size),
            kind: PetLogExportKind.video,
            period: '2026년 10월',
            photos: [
              PetLogExportPhoto(
                logDate: '2026-10-15',
                photo: PetLogPhoto(
                  id: 'fixture',
                  url: 'https://isolated.invalid/photo.jpg',
                  position: 0,
                  width: size.width.toInt(),
                  height: size.height.toInt(),
                ),
              ),
            ],
          ),
        ),
      );
      for (
        var i = 0;
        i < 240 && find.byType(VideoPlayer).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(VideoPlayer), findsOneWidget);
      await tester.pumpAndSettle();
      final video = tester.getRect(find.byType(VideoPlayer));
      final slider = tester.getRect(find.byType(Slider));
      expect(video.width / video.height, closeTo(size.aspectRatio, .01));
      expect(slider.top - video.bottom, inInclusiveRange(12, 16));
      expect(
        tester.getRect(find.text('사진 1장  00:03')).bottom + 24,
        closeTo(video.top, 1),
      );
      expect(find.text('내 기기에 저장').hitTestable(), findsOneWidget);
      expect(find.text('공유하기').hitTestable(), findsOneWidget);
      final label = size.width < size.height ? 'portrait' : 'landscape';
      await File(
        '${directory.path}/preview-$label.png',
      ).writeAsBytes(await binding.takeScreenshot(label));
      await tester.tap(find.byTooltip('재생'));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller
            .value
            .isPlaying,
        isTrue,
      );
      await tester.tap(find.byTooltip('일시정지'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      debugPrint('PREVIEW_SPACING_OK $label video=$video slider=$slider');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
