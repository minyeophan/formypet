import '../../widgets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_ink_well.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_text.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '마이페이지',
        leading: const AppIcon(Icons.pets, color: AppColors.primary, size: 25),
        actions: [
          AppHeaderIconButton(
            key: const Key('my-settings-button'),
            icon: Icons.settings_outlined,
            tooltip: '설정',
            onTap: () => context.push('/my/settings'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in _menuGroups) _MenuGroup(group: group),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: AppText(
                      '앱 버전 v2.04',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.muted,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final _MyMenuGroup group;

  const _MenuGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: AppText(
              group.title,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          for (var index = 0; index < group.items.length; index++)
            _MenuRow(
              item: group.items[index],
              showTopBorder: index > 0,
              onTap: group.items[index].route == null
                  ? null
                  : () => context.push(group.items[index].route!),
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MyMenuItem item;
  final bool showTopBorder;
  final VoidCallback? onTap;

  const _MenuRow({
    required this.item,
    required this.showTopBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: AppInkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: showTopBorder
                ? const Border(top: BorderSide(color: AppColors.border))
                : null,
          ),
          child: Row(
            children: [
              _RowIcon(item: item),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  item.label,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap == null)
                const AppText('준비중', fontSize: 12, color: AppColors.muted)
              else
                const AppDisclosureChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  final _MyMenuItem item;

  const _RowIcon({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppIcon(item.icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

class _MyMenuGroup {
  final String title;
  final List<_MyMenuItem> items;

  const _MyMenuGroup({required this.title, required this.items});
}

class _MyMenuItem {
  final String label;
  final IconData icon;
  final String? route;

  const _MyMenuItem({required this.label, required this.icon, this.route});
}

const _menuGroups = [
  _MyMenuGroup(
    title: '정보',
    items: [
      _MyMenuItem(
        label: '내 프로필 편집',
        icon: Icons.person_outline_rounded,
        route: '/my/profile',
      ),
      _MyMenuItem(
        label: '반려동물 관리',
        icon: Icons.pets_outlined,
        route: '/my/pets',
      ),
      _MyMenuItem(label: '공동집사 관리', icon: Icons.group_outlined),
    ],
  ),
  _MyMenuGroup(
    title: '나의 활동',
    items: [
      _MyMenuItem(
        label: '내가 쓴 글',
        icon: Icons.edit_note_rounded,
        route: '/my/activity?tab=written',
      ),
      _MyMenuItem(
        label: '내가 공감한 글',
        icon: Icons.favorite_border_rounded,
        route: '/my/activity?tab=liked',
      ),
      _MyMenuItem(
        label: '내가 댓글 남긴 글',
        icon: Icons.chat_bubble_outline_rounded,
        route: '/my/activity?tab=commented',
      ),
    ],
  ),
  _MyMenuGroup(
    title: '설정',
    items: [
      _MyMenuItem(
        label: '일반 설정',
        icon: Icons.settings_outlined,
        route: '/my/settings',
      ),
      _MyMenuItem(
        label: '알림 내역',
        icon: Icons.notifications_none_rounded,
        route: '/notifications',
      ),
    ],
  ),
  _MyMenuGroup(
    title: '고객지원',
    items: [
      _MyMenuItem(
        label: '공지사항',
        icon: Icons.campaign_outlined,
        route: '/my/notices',
      ),
      _MyMenuItem(
        label: '고객센터',
        icon: Icons.support_agent_rounded,
        route: '/my/support',
      ),
      _MyMenuItem(
        label: '1대1 문의하기',
        icon: Icons.help_outline_rounded,
        route: '/my/inquiry',
      ),
      _MyMenuItem(
        label: '약관 및 정책',
        icon: Icons.description_outlined,
        route: '/my/policies',
      ),
    ],
  ),
];
