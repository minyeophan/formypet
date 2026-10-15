import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

bool get isPetLogVideoSupported => Platform.isAndroid || Platform.isIOS;
int _requestSequence = 0;
const _channel = MethodChannel('com.formypet/pet_log_video_export');
final _progressListeners = <String, void Function(double)>{};
bool _handlerInstalled = false;

void _installProgressHandler() {
  if (_handlerInstalled) return;
  _handlerInstalled = true;
  _channel.setMethodCallHandler((call) async {
    if (call.method != 'progress' || call.arguments is! Map) return;
    final args = call.arguments as Map;
    final completed = args['completedFrames'];
    final total = args['totalFrames'];
    if (completed is! int || total is! int || total <= 0 || completed < 0) {
      return;
    }
    _progressListeners[args['requestId']]?.call(
      (completed / total).clamp(0, .99),
    );
  });
}

Future<String> createPetLogVideo(
  List<String> imagePaths,
  String outputPath, {
  CancelToken? cancelToken,
  void Function(double)? onProgress,
}) async {
  if (imagePaths.isEmpty) throw ArgumentError('Select at least one photo.');
  if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
  try {
    await File(outputPath).delete();
  } catch (_) {}
  _installProgressHandler();
  const channel = _channel;
  final requestId =
      '${DateTime.now().microsecondsSinceEpoch}-${_requestSequence++}';
  var finished = false;
  var lastProgress = -1.0;
  if (onProgress != null) {
    _progressListeners[requestId] = (value) {
      if (finished ||
          cancelToken?.isCancelled == true ||
          value <= lastProgress) {
        return;
      }
      lastProgress = value;
      onProgress(value);
    };
  }
  cancelToken?.whenCancel.then((_) async {
    if (finished) return;
    _progressListeners.remove(requestId);
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
    _progressListeners.remove(requestId);
  }
  if (path == null ||
      !await File(path).exists() ||
      await File(path).length() == 0) {
    throw StateError('Video export did not produce a file.');
  }
  // iOS has no frame events: preserve its indeterminate loading state.
  if (cancelToken?.isCancelled != true && lastProgress >= 0) onProgress?.call(1);
  return path;
}
