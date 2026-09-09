import '../../widgets/app_icon.dart';
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: state.items.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: item.isRead
          ? AppColors.surface
          : AppColors.primary.withValues(alpha: .12),
      child: AppInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(
                item.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 4),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
