import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/pet_log_video_exporter_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.formypet/pet_log_video_export');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'missing output and native finalization failure never report completion',
    () async {
      final values = <double>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'encode_failed',
          message: 'muxer stop failed',
        );
      });
      await expectLater(
        createPetLogVideo(
          ['photo.jpg'],
          '${Directory.systemTemp.path}/missing-polish.mp4',
          onProgress: values.add,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(values, isEmpty);
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      await expectLater(
        createPetLogVideo(
          ['photo.jpg'],
          '${Directory.systemTemp.path}/missing-polish.mp4',
          onProgress: values.add,
        ),
        throwsStateError,
      );
      expect(values, isEmpty);
    },
  );

  test(
    'progress is request scoped, monotonic and completes only after output exists',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pet-log-progress-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final output = '${directory.path}/result.mp4';
      final ready = Completer<String>();
      final done = Completer<String>();
      final values = <double>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') {
          ready.complete((call.arguments as Map)['requestId'] as String);
          return done.future;
        }
        return null;
      });
      final result = createPetLogVideo(
        ['photo.jpg'],
        output,
        onProgress: values.add,
      );
      final id = await ready.future;
      Future<void> emit(String requestId, int frames) async {
        final finished = Completer<void>();
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('progress', {
              'requestId': requestId,
              'completedFrames': frames,
              'totalFrames': 30,
            }),
          ),
          (_) => finished.complete(),
        );
        await finished.future;
      }

      await emit('different-request', 20);
      await emit(id, 15);
      await emit(id, 3);
      await emit(id, 30);
      expect(values, [.5, .99]);
      await File(output).writeAsBytes([1, 2, 3]);
      done.complete(output);
      expect(await result, output);
      expect(values, [.5, .99, 1]);
      await emit(id, 20);
      expect(values, [.5, .99, 1]);
    },
  );

  test('cancelling one export only targets its request ID', () async {
    final directory = await Directory.systemTemp.createTemp('pet-log-export-');
    final creates = <String, Completer<String>>{};
    final cancellations = <String>[];
    final ready = Completer<void>();
    final cancelReady = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          if (call.method == 'create') {
            final id = args['requestId'] as String;
            creates[id] = Completer<String>();
            if (creates.length == 2) ready.complete();
            return creates[id]!.future;
          }
          if (call.method == 'cancel') {
            cancellations.add(args['requestId'] as String);
            cancelReady.complete();
          }
          return null;
        });

    final firstOutput = '${directory.path}/first.mp4';
    final secondOutput = '${directory.path}/second.mp4';
    final firstToken = CancelToken();
    final first = createPetLogVideo(
      ['first.jpg'],
      firstOutput,
      cancelToken: firstToken,
    );
    final second = createPetLogVideo(['second.jpg'], secondOutput);
    await ready.future;

    final ids = creates.keys.toList();
    firstToken.cancel('test');
    await cancelReady.future;
    expect(cancellations, [ids.first]);

    for (final entry in creates.entries) {
      final output = entry.key == ids.first ? firstOutput : secondOutput;
      await File(output).writeAsBytes([0, 1, 2]);
      entry.value.complete(output);
    }
    expect(await Future.wait([first, second]), [firstOutput, secondOutput]);
    await directory.delete(recursive: true);
  });
}
