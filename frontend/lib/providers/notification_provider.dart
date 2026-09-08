import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isMarkingAllRead;
  final List<NotificationItem> items;
  final String? nextCursor;
  final bool hasMore;
  final int unreadCount;
  final String? errorText;

  const NotificationState({
    required this.isLoading,
    this.isLoadingMore = false,
    this.isMarkingAllRead = false,
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
    bool? isLoadingMore,
    bool? isMarkingAllRead,
    List<NotificationItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    int? unreadCount,
    String? errorText,
    bool clearErrorText = false,
  }) => NotificationState(
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isMarkingAllRead: isMarkingAllRead ?? this.isMarkingAllRead,
    items: items ?? this.items,
    nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
    hasMore: hasMore ?? this.hasMore,
    unreadCount: unreadCount ?? this.unreadCount,
    errorText: clearErrorText ? null : (errorText ?? this.errorText),
  );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service;
  int _session = 0;
  int _feedVersion = 0;
  bool _sessionActive = true;
  final _readingIds = <String>{};

  NotificationNotifier(this._service) : super(NotificationState.initial());

  int get sessionRevision => _session;

  void resetSession({required bool authenticated}) {
    _session++;
    _feedVersion++;
    _sessionActive = authenticated;
    _readingIds.clear();
    if (mounted) state = NotificationState.initial();
  }

  bool _isCurrent(int session) => mounted && _session == session;

  List<NotificationItem> _unique(List<NotificationItem> items) =>
      {for (final item in items) item.id: item}.values.toList();

  Future<void> loadFirstPage() async {
    if (!_sessionActive) return;
    final session = _session;
    final version = ++_feedVersion;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearErrorText: true,
    );
    try {
      final feed = await _service.list();
      if (!_isCurrent(session) || version != _feedVersion) return;
      state = state.copyWith(
        isLoading: false,
        items: _unique(feed.items),
        nextCursor: feed.nextCursor,
        clearNextCursor: feed.nextCursor == null,
        hasMore: feed.hasMore,
        unreadCount: feed.unreadCount,
      );
    } catch (_) {
      if (!_isCurrent(session) || version != _feedVersion) return;
      state = state.copyWith(isLoading: false, errorText: '알림을 불러오지 못했어요.');
      rethrow;
    }
  }

  Future<void> loadMore() async {
    if (!_sessionActive ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }
    final session = _session;
    final version = _feedVersion;
    state = state.copyWith(isLoadingMore: true, clearErrorText: true);
    try {
      final feed = await _service.list(cursor: state.nextCursor);
      if (!_isCurrent(session) || version != _feedVersion) return;
      state = state.copyWith(
        isLoadingMore: false,
        items: _unique([...state.items, ...feed.items]),
        nextCursor: feed.nextCursor,
        clearNextCursor: feed.nextCursor == null,
        hasMore: feed.hasMore,
        unreadCount: feed.unreadCount,
      );
    } catch (_) {
      if (!_isCurrent(session) || version != _feedVersion) return;
      state = state.copyWith(
        isLoadingMore: false,
        errorText: '알림을 더 불러오지 못했어요. 다시 시도해 주세요.',
      );
      rethrow;
    }
  }

  Future<void> markRead(String id) async {
    if (!_sessionActive || !_readingIds.add(id)) return;
    final session = _session;
    try {
      await _service.markRead(id);
    } catch (_) {
      if (!_isCurrent(session)) return;
      rethrow;
    } finally {
      if (_isCurrent(session)) _readingIds.remove(id);
    }
    if (!_isCurrent(session)) return;
    final wasUnread = state.items.any((item) => item.id == id && !item.isRead);
    state = state.copyWith(
      items: state.items
          .map(
            (item) => item.id == id && !item.isRead
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
                : item,
          )
          .toList(),
      unreadCount: wasUnread && state.unreadCount > 0
          ? state.unreadCount - 1
          : state.unreadCount,
    );
  }

  Future<void> markAllRead() async {
    if (!_sessionActive || state.isMarkingAllRead) return;
    final session = _session;
    state = state.copyWith(isMarkingAllRead: true, clearErrorText: true);
    try {
      await _service.markAllRead();
    } catch (_) {
      if (!_isCurrent(session)) return;
      state = state.copyWith(
        isMarkingAllRead: false,
        errorText: '모두 읽음 처리하지 못했어요. 다시 시도해 주세요.',
      );
      rethrow;
    }
    if (!_isCurrent(session)) return;
    _feedVersion++;
    final now = DateTime.now();
    state = state.copyWith(
      isLoading: false,
      isLoadingMore: false,
      isMarkingAllRead: false,
      items: state.items
          .map(
            (item) => item.isRead
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
                  ),
          )
          .toList(),
      unreadCount: 0,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
      (ref) => NotificationNotifier(ref.watch(notificationServiceProvider)),
    );
