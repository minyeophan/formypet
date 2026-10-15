import 'package:dio/dio.dart';
import 'pet_log_video_exporter_stub.dart'
    if (dart.library.io) 'pet_log_video_exporter_native.dart'
    as platform;

class PetLogVideoExporter {
  static bool get isSupported => platform.isPetLogVideoSupported;
  static Future<String> create(
    List<String> paths,
    String output, {
    CancelToken? cancelToken,
    void Function(double)? onProgress,
  }) => platform.createPetLogVideo(paths, output, cancelToken: cancelToken, onProgress: onProgress);
}
