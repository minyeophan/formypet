import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/post.dart';

// 8 community categories
const List<String> kCommunityCategories = [
  'all', 'popular', 'dog', 'cat', 'rabbit', 'hamster', 'bird', 'other',
];

class CommunityService {
  Future<PostFeed> getFeed({
    String category = 'all',
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (category != 'all') params['category'] = category;
    // popular category: cursor format is "likesCount:postId"
    if (cursor != null) params['cursor'] = cursor;

    final res =
        await dio.get('/api/v1/posts', queryParameters: params);
    return PostFeed.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<Post> createPost({
    required String content,
    String? title,
    required String category,
    List<File> files = const [],
  }) async {
    // Backend: multipart with @RequestPart("payload") String + @RequestPart("files")
    final payload = {
      'content': content,
      'category': category,
      if (title != null) 'title': title,
    };

    if (files.isEmpty) {
      // JSON-only path
      final res = await dio.post('/api/v1/posts', data: payload);
      return Post.fromJson(unwrap(res) as Map<String, dynamic>);
    }

    // Multipart path
    final formData = FormData.fromMap({
      'payload': jsonEncode(payload),
      'files': await Future.wait(files.map((f) async => MultipartFile.fromFile(
            f.path,
            filename: f.path.split(Platform.pathSeparator).last,
          ))),
    });
    final res = await dio.post('/api/v1/posts',
        data: formData,
        options: Options(contentType: 'multipart/form-data'));
    return Post.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final res = await dio.post('/api/v1/posts/$postId/like');
    // Returns PostLikeResponse: { postId, liked, likesCount }
    return unwrap(res) as Map<String, dynamic>;
  }
}

