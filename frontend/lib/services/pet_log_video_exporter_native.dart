import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

bool get isPetLogVideoSupported => Platform.isAndroid || Platform.isIOS;
int _requestSequence = 0;

Future<String> createPetLogVideo(
  List<String> imagePaths,
  String outputPath, {
  CancelToken? cancelToken,
}) async {
  if (imagePaths.isEmpty) throw ArgumentError('Select at least one photo.');
  try {
    await File(outputPath).delete();
  } catch (_) {}
  const channel = MethodChannel('com.formypet/pet_log_video_export');
  final requestId =
      '${DateTime.now().microsecondsSinceEpoch}-${_requestSequence++}';
  var finished = false;
  cancelToken?.whenCancel.then((_) async {
    if (finished) return;
    try {
      await channel.invokeMethod<void>('cancel', {'requestId': requestId});
    } catch (_) {
      // The export may finish while the platform cancellation is in flight.
    }
  });
  late final String? path;
  try {
    path = await channel.invokeMethod<String>('create', {
      'requestId': requestId,
      'imagePaths': imagePaths,
      'outputPath': outputPath,
      'secondsPerPhoto': 3,
    });
  } finally {
    finished = true;
  }
  if (path == null || !await File(path).exists()) {
    throw StateError('Video export did not produce a file.');
  }
  return path;
}
