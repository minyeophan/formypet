import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../models/post.dart';

class PollDraft {
  final String question;
  final List<String> options;

  const PollDraft({required this.question, required this.options});

  Map<String, dynamic> toJson() => {'question': question, 'options': options};
}

enum CommunityFeedSort {
  latest('latest'),
  popular('popular');

  const CommunityFeedSort(this.apiValue);
  final String apiValue;
}

class CommunityService {
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) async {
    final normalizedCategory = category?.toUpperCase();
    final normalizedKeyword = keyword?.trim();
    final params = <String, dynamic>{'limit': limit, 'sort': sort.apiValue};
    if (normalizedCategory != null &&
        normalizedCategory != 'ALL' &&
        normalizedCategory != 'POPULAR') {
      params['category'] = normalizedCategory;
    }
    if (cursor != null) params['cursor'] = cursor;
    if (normalizedKeyword != null && normalizedKeyword.isNotEmpty) {
      params['keyword'] = normalizedKeyword;
    }

    final res = await dio.get('/api/v1/posts', queryParameters: params);
    return PostFeed.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<Post> createPost({
    required String content,
    String? title,
    required String category,
    List<XFile> files = const [],
    PollDraft? poll,
  }) async {
    final payload = {
      'content': content,
      'category': category.toUpperCase(),
      'title': ?title,
      if (poll case final poll?) 'poll': poll.toJson(),
    };

    final multipartFiles = <MultipartFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      multipartFiles.add(
        MultipartFile.fromBytes(
          await file.readAsBytes(),
          filename: _filenameFor(file, i),
        ),
      );
    }

    final formData = FormData()
      ..fields.add(MapEntry('payload', jsonEncode(payload)))
      ..files.addAll(multipartFiles.map((file) => MapEntry('files', file)));
    final res = await dio.post(
      '/api/v1/posts',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Post.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final res = await dio.post('/api/v1/posts/$postId/like');
    return unwrap(res) as Map<String, dynamic>;
  }

  Future<Post> getPost(String postId) async {
    final res = await dio.get('/api/v1/posts/$postId');
    return Post.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<Post> vote(String postId, String optionId) async {
    final res = await dio.post(
      '/api/v1/posts/$postId/poll/options/$optionId/vote',
    );
    return Post.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<PostCommentFeed> getComments(
    String postId, {
    String? cursor,
    int limit = 20,
    int replyLimit = 20,
  }) async {
    final res = await dio.get(
      '/api/v1/posts/$postId/comments',
      queryParameters: {
        'cursor': ?cursor,
        'limit': limit,
        'replyLimit': replyLimit,
      },
    );
    return PostCommentFeed.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<PostComment> getCommentThread(
    String postId,
    String commentId, {
    int replyLimit = 20,
  }) async {
    final res = await dio.get(
      '/api/v1/posts/$postId/comments/$commentId',
      queryParameters: {'replyLimit': replyLimit},
    );
    return PostComment.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<PostCommentFeed> getReplies(
    String postId,
    String commentId, {
    String? cursor,
    int limit = 20,
  }) async {
    final res = await dio.get(
      '/api/v1/posts/$postId/comments/$commentId/replies',
      queryParameters: {'cursor': ?cursor, 'limit': limit},
    );
    return PostCommentFeed.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<PostComment> createComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    final res = await dio.post(
      '/api/v1/posts/$postId/comments',
      data: {'content': content.trim(), 'parentCommentId': ?parentCommentId},
    );
    return PostComment.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<PostComment> updateComment(
    String postId,
    String commentId,
    String content,
  ) async {
    final res = await dio.patch(
      '/api/v1/posts/$postId/comments/$commentId',
      data: {'content': content.trim()},
    );
    return PostComment.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await dio.delete('/api/v1/posts/$postId/comments/$commentId');
  }

  String _filenameFor(XFile file, int index) {
    if (file.name.isNotEmpty) return file.name;
    final path = file.path.replaceAll('\\', '/');
    final slash = path.lastIndexOf('/');
    final fromPath = slash >= 0 ? path.substring(slash + 1) : path;
    if (fromPath.isNotEmpty) return fromPath;
    return 'upload-$index';
  }
}
