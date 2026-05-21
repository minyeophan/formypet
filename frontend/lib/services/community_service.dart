import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../models/post.dart';

enum CommunityFeedSort {
  latest('latest'),
  popular('popular');

  const CommunityFeedSort(this.apiValue);
  final String apiValue;
}

const List<String> kCommunityCategories = [
  'CARE',
  'FOOD',
  'OUTING',
  'SHOW',
  'QUESTION',
  'FREE',
  'ADOPTION',
  'RESCUE',
  'NEWS',
  'EVENT',
];

const List<String> kCommunityFeedTabs = [
  'ALL',
  'POPULAR',
  ...kCommunityCategories,
];

const Map<String, String> kCommunityCategoryLabels = {
  'ALL': '전체',
  'POPULAR': '인기',
  'CARE': '케어',
  'FOOD': '사료/간식',
  'OUTING': '산책/외출',
  'SHOW': '자랑',
  'QUESTION': '질문',
  'FREE': '자유',
  'ADOPTION': '입양',
  'RESCUE': '구조',
  'NEWS': '소식',
  'EVENT': '이벤트',
};

class PollDraft {
  final String question;
  final List<String> options;

  const PollDraft({required this.question, required this.options});

  Map<String, dynamic> toJson() => {'question': question, 'options': options};
}

class CommunityService {
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
  }) async {
    final normalizedCategory = category?.toUpperCase();
    final params = <String, dynamic>{'limit': limit, 'sort': sort.apiValue};
    if (normalizedCategory != null &&
        normalizedCategory != 'ALL' &&
        normalizedCategory != 'POPULAR') {
      params['category'] = normalizedCategory;
    }
    if (cursor != null) params['cursor'] = cursor;

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
      if (title case final title?) 'title': title,
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

  String _filenameFor(XFile file, int index) {
    if (file.name.isNotEmpty) return file.name;
    final path = file.path.replaceAll('\\', '/');
    final slash = path.lastIndexOf('/');
    final fromPath = slash >= 0 ? path.substring(slash + 1) : path;
    if (fromPath.isNotEmpty) return fromPath;
    return 'upload-$index';
  }
}
