class NotificationItem {
  final String id;
  final String? actorUserId;
  final String? actorNickname;
  final String type;
  final String? postId;
  final String? commentId;
  final String? sourceType;
  final String? sourceId;
  final DateTime? scheduledFor;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    this.actorUserId,
    this.actorNickname,
    required this.type,
    this.postId,
    this.commentId,
    this.sourceType,
    this.sourceId,
    this.scheduledFor,
    required this.title,
    required this.body,
    this.readAt,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'].toString(),
        actorUserId: _stringOrNull(json['actorUserId']),
        actorNickname: _stringOrNull(json['actorNickname']),
        type: json['type']?.toString() ?? '',
        postId: _stringOrNull(json['postId']),
        commentId: _stringOrNull(json['commentId']),
        sourceType: _stringOrNull(json['sourceType']),
        sourceId: _stringOrNull(json['sourceId']),
        scheduledFor: _dateOrNull(json['scheduledFor']),
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        readAt: _dateOrNull(json['readAt']),
        createdAt: _dateOrNull(json['createdAt']),
      );

  bool get isRead => readAt != null;
}

class NotificationFeed {
  final List<NotificationItem> items;
  final String? nextCursor;
  final bool hasMore;
  final int unreadCount;

  const NotificationFeed({
    required this.items,
    this.nextCursor,
    required this.hasMore,
    required this.unreadCount,
  });

  factory NotificationFeed.fromJson(Map<String, dynamic> json) =>
      NotificationFeed(
        items: ((json['items'] as List<dynamic>?) ?? const [])
            .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        nextCursor: _stringOrNull(json['nextCursor']),
        hasMore: json['hasMore'] == true,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

String? _stringOrNull(dynamic value) => value?.toString();

DateTime? _dateOrNull(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '');
