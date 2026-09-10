import 'post.dart';

enum MyActivityType {
  written('내가 쓴 글', '작성'),
  liked('공감한 글', '공감'),
  commented('댓글 남긴 글', '댓글');

  const MyActivityType(this.label, this.actionLabel);
  final String label;
  final String actionLabel;
  static MyActivityType parse(String? value) =>
      values.firstWhere((type) => type.name == value, orElse: () => written);
}

class MyCommunityActivity {
  final Post post;
  final String activityAt;
  final String? commentId;
  final String? parentId;
  final String? commentContent;
  const MyCommunityActivity({
    required this.post,
    required this.activityAt,
    this.commentId,
    this.parentId,
    this.commentContent,
  });
  factory MyCommunityActivity.fromJson(Map<String, dynamic> json) {
    final comment = json['comment'] as Map<String, dynamic>?;
    return MyCommunityActivity(
      post: Post.fromJson(json['post'] as Map<String, dynamic>),
      activityAt: json['activityAt'] as String,
      commentId: comment?['id']?.toString(),
      parentId: comment?['parentId']?.toString(),
      commentContent: comment?['content'] as String?,
    );
  }
  MyCommunityActivity withPost(Post value) => MyCommunityActivity(
    post: value,
    activityAt: activityAt,
    commentId: commentId,
    parentId: parentId,
    commentContent: commentContent,
  );
}

class MyActivityPage {
  final List<MyCommunityActivity> items;
  final String? nextCursor;
  const MyActivityPage(this.items, this.nextCursor);
  factory MyActivityPage.fromJson(Map<String, dynamic> json) => MyActivityPage(
    (json['items'] as List)
        .map((e) => MyCommunityActivity.fromJson(e as Map<String, dynamic>))
        .toList(),
    json['nextCursor'] as String?,
  );
}
