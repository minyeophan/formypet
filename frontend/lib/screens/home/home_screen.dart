import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pet_colors.dart';
import '../../core/pet_taxonomy.dart';
import '../../core/visuals/app_visual_id.dart';
import '../../models/pet.dart';
import '../../models/post.dart';
import '../../providers/home_popular_posts_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_visual.dart';
import '../../widgets/app_header.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/preparing_toast.dart';
import 'home_v2_tokens.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  PageController? _pageController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(notificationProvider.notifier).loadFirstPage();
      } catch (_) {
        // Notification loading must not prevent the home screen from opening.
      }
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petProvider);
    if (pets.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeIndex = pets.pets.indexWhere((p) => p.id == pets.activePetId);
    final pageIndex = activeIndex < 0 ? 0 : activeIndex;
    _pageController ??= PageController(initialPage: pageIndex);
    _syncPage(pageIndex);

    return Scaffold(
      backgroundColor: HomeV2Tokens.background,
      body: SafeArea(
        child: Column(
          children: [
            const _HomeHeader(),
            Expanded(
              child: pets.activePet == null
                  ? const _EmptyHome()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              HomeV2Tokens.gutter,
                              4,
                              HomeV2Tokens.gutter,
                              0,
                            ),
                            sliver: SliverList.list(
                              children: [
                                _PetProfilePager(
                                  pets: pets.pets,
                                  controller: _pageController!,
                                  activeIndex: pageIndex,
                                  locked: _isRefreshing,
                                  onChanged: (index) {
                                    if (index >= pets.pets.length) return;
                                    ref
                                        .read(petProvider.notifier)
                                        .setActivePet(pets.pets[index].id);
                                  },
                                ),
                                const SizedBox(height: HomeV2Tokens.sectionGap),
                                _QuickMenu(
                                  onPreparing: () =>
                                      showPreparingToast(context),
                                ),
                                const SizedBox(height: HomeV2Tokens.sectionGap),
                                _NewsSection(
                                  onPreparing: () =>
                                      showPreparingToast(context),
                                ),
                                const SizedBox(height: HomeV2Tokens.sectionGap),
                                const _PopularPostsSection(),
                                const SizedBox(height: HomeV2Tokens.sectionGap),
                                const _BottomBanner(),
                                const SizedBox(
                                  key: Key('home-bottom-spacer'),
                                  height: 96,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    Object? error;
    await Future.wait([
      ref.read(petProvider.notifier).refreshPets().catchError((e) {
        error = e;
      }),
      ref.read(homePopularPostsProvider.notifier).refresh().catchError((e) {
        error = e;
      }),
    ]);
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새로고침하지 못했어요. 다시 시도해 주세요.')));
    }
  }

  void _syncPage(int index) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    if ((controller.page?.round() ?? controller.initialPage) == index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.hasClients) controller.jumpToPage(index);
    });
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(notificationProvider).unreadCount > 0;
    return AppHeader(
      key: const Key('home-v2-header'),
      title: 'ForMyPet',
      leading: const Icon(Icons.pets, color: HomeV2Tokens.primary, size: 25),
      actions: [
        IconButton(
          key: const Key('home-notification-button'),
          tooltip: '알림',
          onPressed: () => context.push('/notifications'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (hasUnread)
                const Positioned(
                  key: Key('home-notification-unread-dot'),
                  right: -1,
                  top: -1,
                  child: SizedBox(
                    width: 7,
                    height: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _PetProfilePager extends StatelessWidget {
  const _PetProfilePager({
    required this.pets,
    required this.controller,
    required this.activeIndex,
    required this.locked,
    required this.onChanged,
  });

  final List<Pet> pets;
  final PageController controller;
  final int activeIndex;
  final bool locked;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 178,
        child: PageView.builder(
          controller: controller,
          physics: locked ? const NeverScrollableScrollPhysics() : null,
          itemCount: pets.length,
          onPageChanged: onChanged,
          itemBuilder: (_, index) => _PetProfileCard(pet: pets[index]),
        ),
      ),
      if (pets.length > 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pets.length,
            (index) => AnimatedContainer(
              key: Key('home-pet-dot-$index'),
              duration: const Duration(milliseconds: 160),
              width: index == activeIndex ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              decoration: BoxDecoration(
                color: index == activeIndex
                    ? HomeV2Tokens.primary
                    : HomeV2Tokens.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
    ],
  );
}

class _PetProfileCard extends StatelessWidget {
  const _PetProfileCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('home-profile-card-${pet.id}'),
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(radius: 28),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox.square(
            dimension: 112,
            child: AuthenticatedNetworkImage(
              url: pet.profileImageUrl,
              fit: BoxFit.cover,
              fallback: ColoredBox(
                color: colorPairForHex(pet.accentColor).bgLight,
                child: Center(
                  child: AppVisual(id: speciesVisualId(pet.species), size: 48),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: HomeV2Tokens.text,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('home-growth-button'),
                    tooltip: '성장 기록',
                    onPressed: () => context.push('/records/growth'),
                    icon: const Icon(Icons.show_chart_rounded),
                    color: HomeV2Tokens.primary,
                  ),
                ],
              ),
              Text(
                _compact(pet.breed) ?? '품종 미상',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HomeV2Tokens.textSecondary),
              ),
              const SizedBox(height: 3),
              Text(speciesLabel(pet.species)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Fact(label: '나이', value: _age(pet.birthDate)),
                  ),
                  Expanded(
                    child: _Fact(
                      label: '함께한 날',
                      value: _daysTogether(pet.adoptionDate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: HomeV2Tokens.textSecondary),
      ),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: HomeV2Tokens.brandFont,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _QuickMenu extends StatelessWidget {
  const _QuickMenu({required this.onPreparing});
  final VoidCallback onPreparing;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, AppVisualId, Color, VoidCallback)>[
      (
        'records',
        '반려기록',
        AppVisualId.homeRecords,
        Colors.orange,
        () => context.push('/records'),
      ),
      (
        'wallet',
        '지갑',
        AppVisualId.homeWallet,
        Colors.blue,
        () => context.push('/wallet'),
      ),
      (
        'routine',
        '루틴',
        AppVisualId.homeRoutine,
        Colors.green,
        () => context.push('/routine'),
      ),
      ('pet-log', '반려로그', AppVisualId.homePetLog, Colors.purple, onPreparing),
    ];
    return Row(
      key: const Key('home-menu-panel'),
      children: [
        for (final item in items)
          Expanded(
            child: InkWell(
              key: Key('home-menu-${item.$1}'),
              borderRadius: BorderRadius.circular(16),
              onTap: item.$5,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: item.$4.withValues(alpha: .09),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AppVisual(id: item.$3, color: item.$4, size: 25),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.onPreparing});
  final VoidCallback onPreparing;

  @override
  Widget build(BuildContext context) {
    const news = [
      (AppVisualId.homeNewsSnack, '수제 강아지 간식 레시피: 야채 비스킷'),
      (AppVisualId.homeNewsWalk, '안전하고 즐거운 산책을 위한 준비사항'),
      (AppVisualId.homeNewsDental, '반려동물 치아관리, 거부감 없이 시작하는 법'),
    ];
    return Column(
      key: const Key('home-news-section'),
      children: [
        _SectionHeader(title: '오늘의 뉴스', action: '모두 보기', onTap: onPreparing),
        const SizedBox(height: 10),
        for (final item in news)
          _NewsCard(visual: item.$1, title: item.$2, onTap: onPreparing),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.visual,
    required this.title,
    required this.onTap,
  });
  final AppVisualId visual;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HomeV2Tokens.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Badge(label: '준비중'),
                  const SizedBox(height: 5),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: HomeV2Tokens.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: AppVisual(
                  id: visual,
                  color: HomeV2Tokens.primary,
                  size: 28,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: HomeV2Tokens.textSecondary),
          ],
        ),
      ),
    ),
  );
}

class _PopularPostsSection extends ConsumerWidget {
  const _PopularPostsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homePopularPostsProvider);
    return Column(
      key: const Key('home-popular-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: '오늘의 인기글'),
        const SizedBox(height: 10),
        if (state.isInitialLoading)
          for (var i = 0; i < 3; i++) ...[
            const _PopularSkeleton(),
          ]
        else if (state.initialError != null)
          _PopularMessage(
            message: '인기글을 불러오지 못했어요',
            action: TextButton(
              key: const Key('home-popular-retry'),
              onPressed: () => ref
                  .read(homePopularPostsProvider.notifier)
                  .load()
                  .catchError((_) {}),
              child: const Text('다시 시도'),
            ),
          )
        else if (state.posts.isEmpty)
          const _PopularMessage(message: '아직 인기글이 없어요')
        else
          for (final post in state.posts) ...[
            _PopularPostCard(post: post),
          ],
      ],
    );
  }
}

class _PopularPostCard extends StatelessWidget {
  const _PopularPostCard({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => context.push('/community/posts/${post.id}?source=popular'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HomeV2Tokens.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Badge(label: _categoryLabel(post.category)),
                  const SizedBox(height: 5),
                  Text(
                    _postTitle(post),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Metric(icon: Icons.favorite_border, value: post.likesCount),
            const SizedBox(width: 10),
            _Metric(icon: Icons.chat_bubble_outline, value: post.commentsCount),
          ],
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: HomeV2Tokens.textSecondary),
      const SizedBox(width: 3),
      Text(
        '$value',
        style: const TextStyle(
          fontFamily: HomeV2Tokens.brandFont,
          fontSize: 11,
        ),
      ),
    ],
  );
}

class _PopularSkeleton extends StatelessWidget {
  const _PopularSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    decoration: _cardDecoration(color: HomeV2Tokens.surfaceSoft),
  );
}

class _PopularMessage extends StatelessWidget {
  const _PopularMessage({required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration(),
    child: Column(children: [Text(message), ?action]),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: HomeV2Tokens.primary),
          child: Text(action!),
        ),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: HomeV2Tokens.primarySoft,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: HomeV2Tokens.primary,
      ),
    ),
  );
}

class _BottomBanner extends StatelessWidget {
  const _BottomBanner();
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('home-bottom-banner'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: HomeV2Tokens.primarySoft,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘 하루도 포마이펫과 함께!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                '반려동물의 행복을 기록해요',
                style: TextStyle(color: HomeV2Tokens.textSecondary),
              ),
            ],
          ),
        ),
        AppVisual(id: AppVisualId.homeBottomBanner, size: 54),
      ],
    ),
  );
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('반려동물을 먼저 등록해 주세요'));
}

BoxDecoration _cardDecoration({
  double radius = HomeV2Tokens.radius,
  Color color = HomeV2Tokens.surface,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: HomeV2Tokens.border),
  boxShadow: const [
    BoxShadow(color: Color(0x09000000), blurRadius: 20, offset: Offset(0, 7)),
  ],
);

String? _compact(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

String _postTitle(Post post) =>
    _compact(post.title) ?? _compact(post.content) ?? '내용 없음';

String _categoryLabel(String category) =>
    const {
      'FREE': '자유',
      'QUESTION': '질문',
      'CARE': '돌봄',
      'FOOD': '먹거리',
      'OUTING': '외출',
      'SHOW': '자랑',
    }[category.toUpperCase()] ??
    category;

String _age(String? value) {
  final birth = DateTime.tryParse(value ?? '');
  if (birth == null) return '-';
  final now = DateTime.now();
  var years = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    years--;
  }
  return '${years.clamp(0, 999)}살';
}

String _daysTogether(String? value) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return '-';
  final now = DateTime.now();
  final days =
      DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(date.year, date.month, date.day)).inDays +
      1;
  return days < 1 ? '-' : '$days일';
}
