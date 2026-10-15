import 'package:dio/dio.dart';

Future<String> createPetLogVideo(
  List<String> imagePaths,
  String outputPath, {
  CancelToken? cancelToken,
  void Function(double)? onProgress,
}) async => throw UnsupportedError('Video export is only supported on mobile.');

bool get isPetLogVideoSupported => false;
