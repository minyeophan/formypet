import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_v2_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/blocked_users_provider.dart';
import '../../services/community_safety_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/user_block_sheet.dart';

class MyBlockedUsersScreen extends ConsumerWidget {
  const MyBlockedUsersScreen({super.key});

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    BlockedUser user,
  ) async {
    final actor = ref.read(authProvider).profile?.id;
    final done = await showUserBlockSheet(context, user: user, unblock: true);
    if (!context.mounted ||
        done != true ||
        ref.read(authProvider).profile?.id != actor) {
      return;
    }
    ref.invalidate(blockedUsersProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('차단을 해제했어요.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final users = ref.watch(blockedUsersProvider);
    return Scaffold(
      backgroundColor: AppV2Tokens.background,
      appBar: AppHeader(
        title: '차단 목록',
        showBackButton: true,
        centerTitle: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/my');
          }
        },
      ),
      body: !auth.isAuthenticated || auth.profile == null
          ? const Center(child: Text('로그인 후 차단 목록을 확인해 주세요.'))
          : users.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppV2Tokens.primary),
              ),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('차단 목록을 불러오지 못했어요.'),
                    TextButton(
                      onPressed: () => ref.invalidate(blockedUsersProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('차단한 사용자가 없어요.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppV2Tokens.border),
                      itemBuilder: (context, index) {
                        final user = items[index];
                        return ListTile(
                          key: Key('blocked-user-${user.userId}'),
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: AppV2Tokens.mintSurface,
                            child: Icon(
                              Icons.person_outline,
                              color: AppV2Tokens.primary,
                            ),
                          ),
                          title: Text(user.nickname),
                          trailing: TextButton(
                            onPressed: () => _unblock(context, ref, user),
                            child: const Text(
                              '차단 해제',
                              style: TextStyle(color: AppV2Tokens.primary),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
