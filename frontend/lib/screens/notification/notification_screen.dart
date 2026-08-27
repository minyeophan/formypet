import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../models/notification.dart';
import '../../providers/notification_provider.dart';
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
    Future.microtask(() => ref.read(notificationProvider.notifier).loadFirstPage());
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
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          TextButton(
            onPressed: state.unreadCount == 0
                ? null
                : () => ref.read(notificationProvider.notifier).markAllRead(),
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
    if (state.errorText != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorText!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(notificationProvider.notifier).loadFirstPage(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(child: Text('새로운 알림이 없어요.'));
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(notificationProvider.notifier).loadFirstPage(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return Center(
              child: TextButton(
                onPressed: () => ref.read(notificationProvider.notifier).loadMore(),
                child: const Text('더 보기'),
              ),
            );
          }
          final item = state.items[index];
          return _NotificationTile(
            item: item,
            onTap: item.isRead
                ? null
                : () => ref.read(notificationProvider.notifier).markRead(item.id),
          );
        },
      ),
    );
  }
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
      color: item.isRead ? AppColors.surface : AppColors.primary.withValues(alpha: .12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.isRead ? Icons.notifications_none : Icons.notifications_active,
                  color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(item.body, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (!item.isRead)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 4),
                  child: CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
