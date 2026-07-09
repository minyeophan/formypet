class Post {
  final String id;
  final String userId;
  final String authorNickname;
  final String? authorProfileImageUrl;
  final String? title;
  final String content;
  final String category;
  final int likesCount;
  final bool liked;
  final int commentsCount;
  final List<String> imageUrls;
  final PostPoll? poll;
  final String createdAt;

  const Post({
    required this.id,
    required this.userId,
    required this.authorNickname,
    this.authorProfileImageUrl,
    this.title,
    required this.content,
    required this.category,
    required this.likesCount,
    required this.liked,
    required this.commentsCount,
    required this.imageUrls,
    this.poll,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: j['id'].toString(),
    userId: j['userId'].toString(),
    authorNickname: j['authorNickname'] as String? ?? '',
    authorProfileImageUrl: j['authorProfileImageUrl'] as String?,
    title: j['title'] as String?,
    content: j['content'] as String? ?? '',
    category: j['category'] as String? ?? 'FREE',
    likesCount: j['likesCount'] as int? ?? 0,
    liked: j['liked'] as bool? ?? false,
    commentsCount: j['commentsCount'] as int? ?? 0,
    imageUrls:
        ((j['mediaUrls'] ?? j['imageUrls']) as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    poll: j['poll'] is Map<String, dynamic>
        ? PostPoll.fromJson(j['poll'] as Map<String, dynamic>)
        : null,
    createdAt: j['createdAt'] as String? ?? '',
  );

  Post copyWith({
    bool? liked,
    int? likesCount,
    int? commentsCount,
    PostPoll? poll,
  }) => Post(
    id: id,
    userId: userId,
    authorNickname: authorNickname,
    authorProfileImageUrl: authorProfileImageUrl,
    title: title,
    content: content,
    category: category,
    likesCount: likesCount ?? this.likesCount,
    liked: liked ?? this.liked,
    commentsCount: commentsCount ?? this.commentsCount,
    imageUrls: imageUrls,
    poll: poll ?? this.poll,
    createdAt: createdAt,
  );
}

class PostPoll {
  final String id;
  final String question;
  final List<PostPollOption> options;

  const PostPoll({
    required this.id,
    required this.question,
    required this.options,
  });

  factory PostPoll.fromJson(Map<String, dynamic> j) => PostPoll(
    id: j['id'].toString(),
    question: j['question'] as String? ?? '',
    options: (j['options'] as List<dynamic>? ?? [])
        .map((e) => PostPollOption.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  PostPoll copyWith({List<PostPollOption>? options}) =>
      PostPoll(id: id, question: question, options: options ?? this.options);
}

class PostPollOption {
  final String id;
  final String text;
  final int votesCount;
  final bool votedByMe;

  const PostPollOption({
    required this.id,
    required this.text,
    required this.votesCount,
    required this.votedByMe,
  });

  factory PostPollOption.fromJson(Map<String, dynamic> j) => PostPollOption(
    id: j['id'].toString(),
    text: (j['text'] ?? j['optionText'] ?? j['label'] ?? '').toString(),
    votesCount: j['votesCount'] as int? ?? 0,
    votedByMe: j['votedByMe'] as bool? ?? false,
  );

  PostPollOption copyWith({int? votesCount, bool? votedByMe}) => PostPollOption(
    id: id,
    text: text,
    votesCount: votesCount ?? this.votesCount,
    votedByMe: votedByMe ?? this.votedByMe,
  );
}

class PostComment {
  final String id;
  final String userId;
  final String authorNickname;
  final String? authorProfileImageUrl;
  final String content;
  final String createdAt;
  final String? updatedAt;
  final bool deleted;
  final int commentsCount;
  final String? parentCommentId;
  final int replyCount;
  final List<PostComment> replies;
  final String? repliesNextCursor;

  const PostComment({
    required this.id,
    required this.userId,
    required this.authorNickname,
    this.authorProfileImageUrl,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.deleted = false,
    required this.commentsCount,
    this.parentCommentId,
    this.replyCount = 0,
    this.replies = const [],
    this.repliesNextCursor,
  });

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
    id: j['id'].toString(),
    userId: j['userId']?.toString() ?? '',
    authorNickname: j['authorNickname'] as String? ?? '',
    authorProfileImageUrl: j['authorProfileImageUrl'] as String?,
    content: j['content'] as String? ?? '',
    createdAt: j['createdAt'] as String? ?? '',
    updatedAt: j['updatedAt'] as String?,
    deleted: j['deleted'] as bool? ?? false,
    commentsCount: j['commentsCount'] as int? ?? 0,
    parentCommentId: j['parentCommentId']?.toString(),
    replyCount: j['replyCount'] as int? ?? 0,
    replies: (j['replies'] as List<dynamic>? ?? [])
        .map((e) => PostComment.fromJson(e as Map<String, dynamic>))
        .toList(),
    repliesNextCursor: j['repliesNextCursor'] as String?,
  );

  PostComment copyWith({
    int? commentsCount,
    int? replyCount,
    List<PostComment>? replies,
    String? repliesNextCursor,
    bool clearRepliesNextCursor = false,
  }) => PostComment(
    id: id,
    userId: userId,
    authorNickname: authorNickname,
    authorProfileImageUrl: authorProfileImageUrl,
    content: content,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
    commentsCount: commentsCount ?? this.commentsCount,
    parentCommentId: parentCommentId,
    replyCount: replyCount ?? this.replyCount,
    replies: replies ?? this.replies,
    repliesNextCursor: clearRepliesNextCursor
        ? null
        : repliesNextCursor ?? this.repliesNextCursor,
  );
}

class PostCommentFeed {
  final List<PostComment> items;
  final String? nextCursor;

  const PostCommentFeed({required this.items, this.nextCursor});

  factory PostCommentFeed.fromJson(Map<String, dynamic> j) => PostCommentFeed(
    items: (j['items'] as List<dynamic>? ?? [])
        .map((e) => PostComment.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextCursor: j['nextCursor'] as String?,
  );
}

class PostFeed {
  final List<Post> items;
  final String? nextCursor;

  const PostFeed({required this.items, this.nextCursor});

  factory PostFeed.fromJson(Map<String, dynamic> j) => PostFeed(
    items: (j['items'] as List<dynamic>? ?? [])
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextCursor: j['nextCursor'] as String?,
  );
}
