import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationState {
  final bool isLoading;
  final List<NotificationItem> items;
  final String? nextCursor;
  final bool hasMore;
  final int unreadCount;
  final String? errorText;

  const NotificationState({
    required this.isLoading,
    required this.items,
    this.nextCursor,
    required this.hasMore,
    required this.unreadCount,
    this.errorText,
  });

  factory NotificationState.initial() => const NotificationState(
    isLoading: false,
    items: [],
    hasMore: false,
    unreadCount: 0,
  );

  NotificationState copyWith({
    bool? isLoading,
    List<NotificationItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    int? unreadCount,
    String? errorText,
    bool clearErrorText = false,
  }) => NotificationState(
    isLoading: isLoading ?? this.isLoading,
    items: items ?? this.items,
    nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
    hasMore: hasMore ?? this.hasMore,
    unreadCount: unreadCount ?? this.unreadCount,
    errorText: clearErrorText ? null : (errorText ?? this.errorText),
  );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service;

  NotificationNotifier(this._service) : super(NotificationState.initial());

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearErrorText: true);
    try {
      final feed = await _service.list();
      state = state.copyWith(
        isLoading: false,
        items: feed.items,
        nextCursor: feed.nextCursor,
        clearNextCursor: feed.nextCursor == null,
        hasMore: feed.hasMore,
        unreadCount: feed.unreadCount,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorText: '알림을 불러오지 못했어요.');
      rethrow;
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.nextCursor == null) return;
    final feed = await _service.list(cursor: state.nextCursor);
    state = state.copyWith(
      items: [...state.items, ...feed.items],
      nextCursor: feed.nextCursor,
      clearNextCursor: feed.nextCursor == null,
      hasMore: feed.hasMore,
      unreadCount: feed.unreadCount,
    );
  }

  Future<void> markRead(String id) async {
    await _service.markRead(id);
    state = state.copyWith(
      items: state.items
          .map((item) => item.id == id && !item.isRead
              ? NotificationItem(
                  id: item.id,
                  actorUserId: item.actorUserId,
                  actorNickname: item.actorNickname,
                  type: item.type,
                  postId: item.postId,
                  commentId: item.commentId,
                  sourceType: item.sourceType,
                  sourceId: item.sourceId,
                  scheduledFor: item.scheduledFor,
                  title: item.title,
                  body: item.body,
                  readAt: DateTime.now(),
                  createdAt: item.createdAt,
                )
              : item)
          .toList(),
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    final now = DateTime.now();
    state = state.copyWith(
      items: state.items
          .map((item) => item.isRead
              ? item
              : NotificationItem(
                  id: item.id,
                  actorUserId: item.actorUserId,
                  actorNickname: item.actorNickname,
                  type: item.type,
                  postId: item.postId,
                  commentId: item.commentId,
                  sourceType: item.sourceType,
                  sourceId: item.sourceId,
                  scheduledFor: item.scheduledFor,
                  title: item.title,
                  body: item.body,
                  readAt: now,
                  createdAt: item.createdAt,
                ))
          .toList(),
      unreadCount: 0,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(ref.watch(notificationServiceProvider)),
);
