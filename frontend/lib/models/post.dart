class Post {
  final String id;
  final String userId; // NOT in RN type — backend has this
  final String authorNickname; // backend: authorNickname (NOT author)
  final String? authorProfileImageUrl;
  final String? title; // VARCHAR(120)
  final String content;
  final String category;
  final int likesCount; // backend: likesCount (NOT likes)
  final bool liked; // backend: liked (NOT likedByMe)
  final int commentsCount;
  final List<String> imageUrls;
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
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'].toString(),
        userId: j['userId'].toString(),
        authorNickname: j['authorNickname'] as String? ?? '',
        authorProfileImageUrl: j['authorProfileImageUrl'] as String?,
        title: j['title'] as String?,
        content: j['content'] as String,
        category: j['category'] as String? ?? 'general',
        likesCount: j['likesCount'] as int? ?? 0,
        liked: j['liked'] as bool? ?? false,
        commentsCount: j['commentsCount'] as int? ?? 0,
        imageUrls: (j['imageUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdAt: j['createdAt'] as String? ?? '',
      );

  Post copyWith({bool? liked, int? likesCount}) => Post(
        id: id,
        userId: userId,
        authorNickname: authorNickname,
        authorProfileImageUrl: authorProfileImageUrl,
        title: title,
        content: content,
        category: category,
        likesCount: likesCount ?? this.likesCount,
        liked: liked ?? this.liked,
        commentsCount: commentsCount,
        imageUrls: imageUrls,
        createdAt: createdAt,
      );
}

class PostFeed {
  final List<Post> items;
  final String? nextCursor;

  const PostFeed({required this.items, this.nextCursor});

  factory PostFeed.fromJson(Map<String, dynamic> j) => PostFeed(
        items: (j['items'] as List<dynamic>)
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: j['nextCursor'] as String?,
      );
}
