import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/pet_taxonomy.dart';
import '../../models/pet.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/preparing_toast.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petState = ref.watch(petProvider);
    final representativePet = petState.activePet ?? petState.pets.firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: '마이페이지',
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
                  _MyPetsSection(
                    pet: representativePet,
                    isLoading: petState.isLoading,
                    onViewAll: () => context.push('/my/pets'),
                  ),
                  for (final group in _menuGroups)
                    _MenuGroup(
                      group: group,
                      onRowTap: (item) => item.label == '내 프로필 편집'
                          ? context.push('/my/profile')
                          : showPreparingToast(context),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 112),
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

class _MyPetsSection extends StatelessWidget {
  final Pet? pet;
  final bool isLoading;
  final VoidCallback onViewAll;

  const _MyPetsSection({
    required this.pet,
    required this.isLoading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF41B883),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF41B883).withValues(alpha: 0.16),
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: AppText(
                  '마이펫',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              TextButton(
                key: const Key('my-view-all-pets'),
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const AppText(
                  '모두보기',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 126,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: isLoading
                      ? const _CardSurface(
                          minHeight: 126,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : pet == null
                      ? const _EmptyPetCard()
                      : _PetCard(
                          key: Key('my-pet-card-${pet!.id}'),
                          pet: pet!,
                          onTap: () => context.push('/pet/${pet!.id}'),
                        ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 116,
                  child: _AddPetCard(onTap: () => context.push('/pets/new')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;

  const _PetCard({super.key, required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta =
        '${speciesLabel(pet.species)} · ${_petAgeLabel(pet.birthDate)}';
    final weight = pet.weight == null
        ? '체중 미등록'
        : '${_numberLabel(pet.weight!)} kg';

    return _CardInk(
      minHeight: 126,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _PetPhotoTile(pet: pet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    pet.name,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    '$meta\n$weight · ${_neuteredLabel(pet.neutered)}',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _PetPhotoTile extends StatelessWidget {
  final Pet pet;

  const _PetPhotoTile({required this.pet});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF1E8), Color(0xFFE8F7EF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        Icons.photo_camera_outlined,
        size: 30,
        color: AppColors.textSecondary,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AuthenticatedNetworkImage(
        url: pet.profileImageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}

class _EmptyPetCard extends StatelessWidget {
  const _EmptyPetCard();

  @override
  Widget build(BuildContext context) {
    return const _CardSurface(
      minHeight: 126,
      child: Center(
        child: AppText(
          '등록된 펫이 없어요',
          fontSize: 13,
          color: AppColors.textSecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _AddPetCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPetCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CardInk(
      key: const Key('my-add-pet-card'),
      minHeight: 126,
      onTap: onTap,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AddIconTile(),
          SizedBox(height: 8),
          AppText(
            '펫 추가하기',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AddIconTile extends StatelessWidget {
  const _AddIconTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Color(0xFF41B883),
          size: 28,
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final _MyMenuGroup group;
  final void Function(_MyMenuItem item) onRowTap;

  const _MenuGroup({required this.group, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              onTap: () => onRowTap(group.items[index]),
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MyMenuItem item;
  final bool showTopBorder;
  final VoidCallback onTap;

  const _MenuRow({
    required this.item,
    required this.showTopBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
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
        child: Icon(item.icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

class _CardInk extends StatelessWidget {
  final double minHeight;
  final VoidCallback onTap;
  final Widget child;

  const _CardInk({
    super.key,
    required this.minHeight,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      minHeight: minHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  final double minHeight;
  final Widget child;

  const _CardSurface({required this.minHeight, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A2A18).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
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

  const _MyMenuItem({required this.label, required this.icon});
}

const _menuGroups = [
  _MyMenuGroup(
    title: '정보',
    items: [
      _MyMenuItem(label: '내 프로필 편집', icon: Icons.person_outline_rounded),
      _MyMenuItem(label: '공동집사 관리', icon: Icons.group_outlined),
    ],
  ),
  _MyMenuGroup(
    title: '나의 활동',
    items: [
      _MyMenuItem(label: '내가 쓴 글', icon: Icons.edit_note_rounded),
      _MyMenuItem(label: '내가 공감한 글', icon: Icons.favorite_border_rounded),
      _MyMenuItem(label: '내가 댓글 남긴 글', icon: Icons.chat_bubble_outline_rounded),
    ],
  ),
  _MyMenuGroup(
    title: '설정',
    items: [
      _MyMenuItem(label: '일반 설정', icon: Icons.settings_outlined),
      _MyMenuItem(label: '알림 설정', icon: Icons.notifications_none_rounded),
    ],
  ),
  _MyMenuGroup(
    title: '고객지원',
    items: [
      _MyMenuItem(label: '공지사항', icon: Icons.campaign_outlined),
      _MyMenuItem(label: '고객센터', icon: Icons.support_agent_rounded),
      _MyMenuItem(label: '1대1 문의하기', icon: Icons.help_outline_rounded),
      _MyMenuItem(label: '약관 및 정책', icon: Icons.description_outlined),
    ],
  ),
];

String _petAgeLabel(String? birthDateIso) {
  final birth = DateTime.tryParse(birthDateIso ?? '');
  if (birth == null) {
    return '나이 미등록';
  }
  final now = DateTime.now();
  var years = now.year - birth.year;
  final hasBirthdayPassed =
      now.month > birth.month ||
      (now.month == birth.month && now.day >= birth.day);
  if (!hasBirthdayPassed) {
    years -= 1;
  }
  return '${years < 0 ? 0 : years}살';
}

String _neuteredLabel(bool? neutered) {
  if (neutered == null) {
    return '중성화 미등록';
  }
  return neutered ? '중성화 완료' : '중성화 미완료';
}

String _numberLabel(double value) {
  final label = value.toStringAsFixed(1);
  return label.endsWith('.0') ? label.substring(0, label.length - 2) : label;
}
