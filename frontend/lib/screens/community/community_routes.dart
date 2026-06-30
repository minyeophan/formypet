import 'community_constants.dart';

String communityPostPath(String postId, String? sourceKey) {
  final source = normalizeCommunitySourceKey(sourceKey);
  return Uri(
    path: '/community/posts/$postId',
    queryParameters: source.isEmpty ? null : {'from': source},
  ).toString();
}

String communityCommentsPath(
  String postId,
  String? sourceKey, {
  bool focus = false,
  String? threadId,
  String? replyToCommentId,
}) {
  final source = normalizeCommunitySourceKey(sourceKey);
  return Uri(
    path: '/community/posts/$postId/comments',
    queryParameters: {
      if (source.isNotEmpty) 'from': source,
      if (focus) 'focus': 'true',
      'thread': ?threadId,
      'replyTo': ?replyToCommentId,
    },
  ).toString();
}

String communityFallbackPath(String? sourceKey) {
  final source = normalizeCommunitySourceKey(sourceKey);
  if (source.isEmpty || source == 'popular') return '/community';
  if (source == 'all') return '/community/category/ALL';
  return '/community/category/$source';
}
