import 'dart:io';

import 'package:dio/dio.dart';

import '../core/api_client.dart';

class MediaService {
  // PRIVATE media — requires auth header (pet profiles, record media, user photos)
  String privateUrl(String mediaId) => '/api/v1/media/$mediaId';

  // PUBLIC media — no auth required (community post images)
  String publicUrl(String mediaId) => '/api/v1/public/media/$mediaId';

  // Build absolute URL from a relative path returned by backend
  String absoluteUrl(String relativePath) {
    final base = dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base$relativePath';
  }

  // Upload pet photo
  Future<String> uploadPetPhoto(String petId, String filePath) async {
    final form = await _buildForm(filePath);
    final res = await dio.post('/api/v1/pets/$petId/media', data: form);
    return (unwrap(res) as Map<String, dynamic>)['url'].toString();
  }

  Future<FormData> _buildForm(String filePath) async {
    return FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split(Platform.pathSeparator).last,
      ),
    });
  }
}
