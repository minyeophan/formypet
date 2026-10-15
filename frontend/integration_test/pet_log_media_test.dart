// No production startup, credentials, backend, or user-record writes.
// flutter test integration_test/pet_log_media_test.dart
//   -d <device> --dart-define=ISOLATED_MEDIA_TEST=true
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/screens/pet_log/pet_log_export_screen.dart';
import 'package:frontend/services/pet_log_video_exporter.dart';
import 'package:frontend/services/pet_log_video_preview.dart';
import 'package:frontend/services/pet_log_service.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated Android 1/5-photo video, progress, preview, save and share',
    (tester) async {
      expect(
        const bool.fromEnvironment('ISOLATED_MEDIA_TEST'),
        isTrue,
        reason:
            'Use the separate .mediatest package; never replace the Play app.',
      );
      final directory = (await getExternalStorageDirectory())!;
      expect(
        directory.path,
        contains('com.formypet.frontend.mediatest/'),
        reason: 'Refuse fixtures or UI actions in the installed user app.',
      );
      final bytes = List.generate(5, (i) {
        final image = img.Image(
          width: i.isEven ? 240 : 360,
          height: i.isEven ? 360 : 240,
        );
        img.fill(
          image,
          color: img.ColorRgb8(i * 40, 180 - i * 20, 70 + i * 30),
        );
        img.fillRect(
          image,
          x1: 10,
          y1: 10,
          x2: 40,
          y2: 80,
          color: img.ColorRgb8(255, 255, 255),
        );
        return Uint8List.fromList(img.encodeJpg(image));
      });
      final paths = <String>[];
      for (var i = 0; i < bytes.length; i++) {
        final file = File('${directory.path}/fixture-$i.jpg');
        await file.writeAsBytes(bytes[i]);
        paths.add(file.path);
      }
      for (final count in [1, 5]) {
        final progress = <double>[];
        final path = await PetLogVideoExporter.create(
          paths.take(count).toList(),
          '${directory.path}/verified-$count.mp4',
          onProgress: progress.add,
        );
        expect(progress.length, greaterThan(2));
        expect(progress.last, 1);
        expect(progress.take(progress.length - 1).every((p) => p < 1), isTrue);
        for (var i = 1; i < progress.length; i++) {
          expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
        }
        final player = await createPetLogVideoPreview(path);
        await player.initialize();
        expect(
          player.value.duration.inMilliseconds,
          closeTo(count * 3000, 150),
        );
        expect(player.value.aspectRatio, closeTo(240 / 360, .02));
        await player.dispose();
        debugPrint(
          'MEDIA_VERIFIED $count photos ${progress.length} progress events',
        );
      }
      initApiClient('https://isolated.invalid', includeAuthInterceptor: false);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            debugPrint('FIXTURE_GET ${request.path}');
            expectSync(request.method, 'GET');
            if (request.path.endsWith('.jpg')) {
              final index = int.parse(
                Uri.parse(request.path).pathSegments.last.split('.').first,
              );
              handler.resolve(
                Response(requestOptions: request, data: bytes[index]),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'data': {
                    'items': [
                      {
                        'id': '1',
                        'petId': '1',
                        'date': '2026-10-15',
                        'time': '12:00:00',
                        'version': 1,
                        'photos': List.generate(
                          5,
                          (i) => {
                            'id': '$i',
                            'url': 'https://isolated.invalid/$i.jpg',
                            'position': i,
                            'width': 240,
                            'height': 360,
                          },
                        ),
                      },
                    ],
                    'years': [2026],
                    'hasAny': true,
                    'nextCursor': null,
                  },
                },
              ),
            );
          },
          onError: (error, handler) {
            debugPrint(
              'FIXTURE_ERROR ${error.type} ${error.message} ${error.error}',
            );
            handler.next(error);
          },
        ),
      );
      final fixturePage = await tester.runAsync(
        () => PetLogService().list('1', year: 2026, month: 10),
      );
      expect(fixturePage!.items.single.photos.length, 5);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const PetLogExportScreen(
            petId: '1',
            year: 2026,
            month: 10,
            all: false,
            kind: PetLogExportKind.video,
          ),
        ),
      );
      await _until(
        tester,
        () => find.byKey(const ValueKey('0')).evaluate().isNotEmpty,
      );
      for (var i = 0; i < 5; i++) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('$i')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(ValueKey('$i')));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(FilledButton, '영상 만들기'));
      await _until(tester, () => find.text('공유하기').evaluate().isNotEmpty);
      final controller = tester
          .widget<VideoPlayer>(find.byType(VideoPlayer))
          .controller;
      expect(controller.value.isPlaying, isFalse);
      expect(controller.value.duration.inMilliseconds, closeTo(15000, 150));
      await tester.tap(find.byTooltip('재생'));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.value.isPlaying, isTrue);
      await tester.tap(find.byTooltip('일시정지'));
      await tester.pump();
      await tester.drag(find.byType(Slider), const Offset(90, 0));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.value.position.inSeconds, greaterThan(1));
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await File(
        '${directory.path}/preview.png',
      ).writeAsBytes(await binding.takeScreenshot('preview'));
      const gallery = MethodChannel('gal');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final code in ['ACCESS_DENIED', 'NOT_ENOUGH_SPACE']) {
        messenger.setMockMethodCallHandler(gallery, (call) async {
          if (call.method == 'requestAccess') return true;
          throw PlatformException(code: code);
        });
        await tester.ensureVisible(find.text('내 기기에 저장'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('내 기기에 저장'));
        await _until(
          tester,
          () => find
              .text(
                code == 'ACCESS_DENIED' ? '사진 저장 권한이 필요해요' : '결과물을 저장하지 못했어요',
              )
              .evaluate()
              .isNotEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(code == 'ACCESS_DENIED' ? '나중에' : '미리보기로 돌아가기'),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
          same(controller),
        );
      }
      messenger.setMockMethodCallHandler(gallery, null);
      await tester.ensureVisible(find.text('내 기기에 저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 기기에 저장'));
      await _until(tester, () => find.text('저장 완료').evaluate().isNotEmpty);
      debugPrint('MEDIA_GALLERY_SAVE_OK');
      await tester.tap(find.text('공유하기'));
      await tester.pump(const Duration(seconds: 2));
      debugPrint('MEDIA_SHARE_OPENED: dismiss Android chooser to continue');
      debugPrint('MEDIA_ARTIFACTS ${directory.path}');
      await tester.pump(const Duration(seconds: 60));
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 240 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(done(), isTrue);
}
