import 'dart:typed_data';

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
  Future<String> uploadPetPhoto({
    required String petId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final form = _buildBytesForm(bytes: bytes, filename: filename);
    final res = await dio.post('/api/v1/pets/$petId/media', data: form);
    return (unwrap(res) as Map<String, dynamic>)['url'].toString();
  }

  FormData _buildBytesForm({
    required Uint8List bytes,
    required String filename,
  }) {
    return FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
  }
}
