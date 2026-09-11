import '../../core/app_v2_tokens.dart';
import '../community/community_constants.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_ink_well.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/notification.dart';
import '../../providers/notification_provider.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await _handleAction(
        ref.read(notificationProvider.notifier).loadFirstPage,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '알림',
        showBackButton: true,
        centerTitle: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
        actions: [
          TextButton(
            onPressed: state.unreadCount == 0 || state.isMarkingAllRead
                ? null
                : () => _handleAction(
                    ref.read(notificationProvider.notifier).markAllRead,
                  ),
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: _NotificationBody(state: state),
    );
  }
}

class _NotificationBody extends ConsumerWidget {
  final NotificationState state;
  const _NotificationBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final notifier = ref.read(notificationProvider.notifier);
    return Column(
      children: [
        if (state.errorText != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(state.errorText!),
                OutlinedButton(
                  onPressed: state.isLoading
                      ? null
                      : () => _handleAction(notifier.loadFirstPage),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _handleAction(notifier.loadFirstPage),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (state.items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('새로운 알림이 없어요.')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 32),
                    sliver: SliverList.separated(
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox.shrink(),
                      itemBuilder: (context, index) {
                        if (index == state.items.length) {
                          return Center(
                            child: TextButton(
                              onPressed: state.isLoadingMore || state.isLoading
                                  ? null
                                  : () => _handleAction(notifier.loadMore),
                              child: Text(
                                state.isLoadingMore ? '불러오는 중...' : '더 보기',
                              ),
                            ),
                          );
                        }
                        final item = state.items[index];
                        return _NotificationTile(
                          item: item,
                          onTap: () => _openNotification(context, ref, item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _handleAction(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    // The notifier retains the list and exposes the error with a retry action.
  }
}

Future<void> _openNotification(
  BuildContext context,
  WidgetRef ref,
  NotificationItem item,
) async {
  final notifications = ref.read(notificationProvider.notifier);
  final session = notifications.sessionRevision;
  if (!item.isRead) {
    try {
      await notifications.markRead(item.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('알림을 읽음 처리하지 못했어요.')));
      }
      return;
    }
  }

  if (!context.mounted || notifications.sessionRevision != session) return;
  if (GoRouter.maybeOf(context) == null) return;
  switch (item.type) {
    case 'COMMENT':
      _pushComment(context, item, reply: false);
    case 'REPLY':
      _pushComment(context, item, reply: true);
    case 'POST_LIKE':
    case 'POLL_VOTE':
      _pushPost(context, item.postId);
    case 'ROUTINE_REMINDER':
    case 'CARE_SCHEDULE_REMINDER':
      final sourceId = item.sourceId;
      if (sourceId == null || sourceId.isEmpty) {
        _showMissingTarget(context);
      } else {
        try {
          final schedule = item.type == 'CARE_SCHEDULE_REMINDER';
          final found = await ref
              .read(petProvider.notifier)
              .activateReminderTarget(sourceId: sourceId, isSchedule: schedule);
          if (!context.mounted || notifications.sessionRevision != session) {
            return;
          }
          if (!found) {
            _showMissingTarget(context);
            return;
          }
          context.push(
            schedule ? '/routine/schedule/$sourceId' : '/routine/$sourceId',
          );
        } catch (_) {
          if (!context.mounted || notifications.sessionRevision != session) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('연결된 내용을 불러오지 못했어요. 다시 시도해 주세요.')),
          );
        }
      }
    default:
      _showMissingTarget(context);
  }
}

void _pushPost(BuildContext context, String? postId) {
  if (postId == null || postId.isEmpty) {
    _showMissingTarget(context);
    return;
  }
  context.push('/community/posts/$postId');
}

void _pushComment(
  BuildContext context,
  NotificationItem item, {
  required bool reply,
}) {
  final postId = item.postId;
  final commentId = item.commentId;
  if (postId == null ||
      postId.isEmpty ||
      commentId == null ||
      commentId.isEmpty) {
    _showMissingTarget(context);
    return;
  }
  final parameter = reply ? 'replyTo' : 'thread';
  context.push('/community/posts/$postId/comments?$parameter=$commentId');
}

void _showMissingTarget(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('연결된 내용을 찾을 수 없어요.')));
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback? onTap;
  const _NotificationTile({required this.item, this.onTap});

  String get _title {
    final title = item.title.trim();
    if (title.isNotEmpty && title != item.type) return title;
    return switch (item.type) {
      'COMMENT' => '새 댓글',
      'REPLY' => '새 답글',
      'POST_LIKE' => '새 공감',
      'POLL_VOTE' => '새 투표',
      'ROUTINE_REMINDER' => '루틴 알림',
      'CARE_SCHEDULE_REMINDER' => '케어 일정 알림',
      _ => '알림',
    };
  }

  @override
  Widget build(BuildContext context) {
    final time = item.createdAt == null
        ? null
        : formatCommunityRelativeTime(item.createdAt!.toIso8601String());
    return Material(
      key: ValueKey('notification-row-${item.id}'),
      color: AppV2Tokens.surface,
      child: AppInkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppV2Tokens.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: item.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: AppV2Tokens.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!item.isRead) ...[
                    Semantics(
                      label: '읽지 않음',
                      child: const CircleAvatar(
                        radius: 3,
                        backgroundColor: AppV2Tokens.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (time != null)
                    Flexible(
                      child: Text(
                        time,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppV2Tokens.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppV2Tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
