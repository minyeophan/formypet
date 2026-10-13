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
