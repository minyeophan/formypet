import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../models/pet_log.dart';
import '../../models/pet.dart';
import '../../providers/pet_provider.dart';
import '../../services/pet_log_service.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_confirmation_sheet.dart';

final _petLogService = PetLogService();

Widget _photoRetryPlaceholder(
  BuildContext context,
  VoidCallback retry, {
  bool dark = false,
}) => Container(
  width: double.infinity,
  height: 220,
  color: dark ? Colors.black : AppColors.surfaceSoft,
  alignment: Alignment.center,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '사진을 불러오지 못했어요.',
        style: TextStyle(color: dark ? Colors.white : AppColors.text),
      ),
      TextButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh),
        label: const Text('다시 불러오기'),
      ),
    ],
  ),
);

class PetLogScreen extends ConsumerStatefulWidget {
  const PetLogScreen({super.key});
  @override
  ConsumerState<PetLogScreen> createState() => _PetLogScreenState();
}

class PetLogBookScreen extends ConsumerStatefulWidget {
  const PetLogBookScreen({super.key});
  @override
  ConsumerState<PetLogBookScreen> createState() => _PetLogBookScreenState();
}

class _PetLogBookScreenState extends ConsumerState<PetLogBookScreen> {
  List<PetLog> _items = [];
  final _scroll = ScrollController();
  String? _nextCursor;
  List<int> _years = [];
  bool _hasAny = false;
  bool _loadingMore = false;
  int _requestGeneration = 0;
  int _year = DateTime.now().year;
  int? _month;
  bool _all = false;
  bool _loading = true;
  bool _changingPeriod = false;
  String? _error;
  String? _petId;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    PetLogService.dataRevision.addListener(_onDataChanged);
    _load();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    PetLogService.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 500) _loadMore();
  }

  Future<void> _load() async {
    final generation = ++_requestGeneration;
    final pet = ref.read(petProvider).activePetId;
    if (pet == null) {
      _petId = null;
      setState(() {
        _items = [];
        _nextCursor = null;
        _loadingMore = false;
        _years = [];
        _hasAny = false;
        _error = null;
        _loading = false;
      });
      return;
    }
    if (_petId != pet) {
      _items = [];
      _nextCursor = null;
      _years = [];
      _hasAny = false;
      _year = DateTime.now().year;
      _month = null;
      _all = false;
    }
    _petId = pet;
    setState(() => _loading = true);
    try {
      final page = await _petLogService.list(
        pet,
        year: _all ? null : _year,
        month: _month,
      );
      if (!mounted ||
          generation != _requestGeneration ||
          pet != ref.read(petProvider).activePetId) {
        return;
      }
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _years = page.years;
        _hasAny = page.hasAny;
        _loadingMore = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = '기록집을 불러오지 못했어요. 현재 기록은 그대로 표시하고 있어요.');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기록집을 불러오지 못했어요.')));
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final pet = _petId, cursor = _nextCursor;
    if (pet == null || cursor == null || _loadingMore) return;
    final generation = _requestGeneration;
    setState(() => _loadingMore = true);
    try {
      final page = await _petLogService.list(
        pet,
        year: _all ? null : _year,
        month: _month,
        cursor: cursor,
      );
      if (!mounted ||
          generation != _requestGeneration ||
          pet != ref.read(petProvider).activePetId) {
        return;
      }
      setState(() {
        _items = [..._items, ...page.items];
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기록을 더 불러오지 못했어요.')));
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _period() async {
    final initial = (_year, _month, _all);
    var year = _year, month = _month;
    var all = _all;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => set(() => year--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('$year년'),
                    IconButton(
                      onPressed: () => set(() => year++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => set(() {
                        all = true;
                        month = null;
                      }),
                      child: const Text('전체 기간'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final availableYear in _years)
                      ChoiceChip(
                        label: Text('$availableYear년'),
                        selected: year == availableYear && !all,
                        onSelected: (_) => set(() {
                          year = availableYear;
                          month = null;
                          all = false;
                        }),
                      ),
                    for (var m = 1; m <= 12; m++)
                      ChoiceChip(
                        label: Text('$m월'),
                        selected: month == m && !all,
                        onSelected: (_) => set(() {
                          month = m;
                          all = false;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('적용'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply != true ||
        (year == initial.$1 && month == initial.$2 && all == initial.$3)) {
      return;
    }
    final generation = ++_requestGeneration;
    final pet = ref.read(petProvider).activePetId;
    if (pet == null) return;
    setState(() => _changingPeriod = true);
    try {
      final page = await _petLogService.list(
        pet,
        year: all ? null : year,
        month: month,
      );
      if (!mounted ||
          generation != _requestGeneration ||
          pet != ref.read(petProvider).activePetId) {
        return;
      }
      setState(() {
        _year = year;
        _month = month;
        _all = all;
        _items = page.items;
        _nextCursor = page.nextCursor;
        _years = page.years;
        _hasAny = page.hasAny;
        _error = null;
        _loadingMore = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = '선택한 기간을 불러오지 못했어요. 현재 기록은 그대로 표시하고 있어요.');
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _changingPeriod = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petProvider);
    final activePetId = petState.activePetId;
    if (activePetId != _petId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    final title = _all
        ? '전체 기간'
        : '$_year년${_month == null ? ' 전체' : ' $_month월'}';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('기록집'),
        actions: [
          IconButton(
            onPressed: _changingPeriod ? null : _period,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _changingPeriod ? null : _period,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(title),
                  ),
                ),
                Text('${_items.length}개 기록'),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(onPressed: _load, child: Text(_error!)),
            ),
          Expanded(
            child: activePetId == null
                ? const Center(child: Text('아이를 먼저 등록해 주세요.'))
                : _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Text(
                      _error ?? (_hasAny ? '선택한 기간에는 기록이 없어요' : '아직 기록이 없어요'),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _items.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final item = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/pet-log/${item.id}', extra: item),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.8,
                                  child: AuthenticatedNetworkImage(
                                    url: item.cover?.url,
                                    fallback: const ColoredBox(
                                      color: AppColors.surfaceSoft,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: _photoRetryPlaceholder,
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  bottom: 12,
                                  child: Text(
                                    '${item.date}  ${item.time.substring(0, min(5, item.time.length))}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PetLogScreenState extends ConsumerState<PetLogScreen> {
  List<PetLog> _items = [];
  final _scroll = ScrollController();
  String? _nextCursor;
  bool _loadingMore = false;
  int _requestGeneration = 0;
  bool _loading = true;
  String? _error;
  String? _moreError;
  String? _petId;
  bool _exampleDismissed = true;
  bool _initialLoadStarted = false;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    PetLogService.dataRevision.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) _load(force: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    PetLogService.dataRevision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 500) _loadMore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadStarted) return;
    _initialLoadStarted = true;
    _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    final id = ref.read(petProvider).activePetId;
    if (id == null) {
      _petId = null;
      setState(() {
        _items = [];
        _nextCursor = null;
        _loading = false;
      });
      return;
    }
    if (_petId == id && !_loading && !force) return;
    final generation = ++_requestGeneration;
    if (_petId != id) {
      _items = [];
      _nextCursor = null;
      _error = null;
      _exampleDismissed = true;
    }
    _petId = id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _petLogService.list(id);
      final dismissed = await _petLogService.exampleDismissed(id);
      if (!mounted ||
          generation != _requestGeneration ||
          ref.read(petProvider).activePetId != id) {
        return;
      }
      setState(() {
        _error = null;
        _exampleDismissed = dismissed;
        _items = page.items
          ..sort(
            (a, b) => DateTime.parse(
              '${b.date}T${b.time}',
            ).compareTo(DateTime.parse('${a.date}T${a.time}')),
          );
        _nextCursor = page.nextCursor;
        _loadingMore = false;
        _moreError = null;
      });
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = '기록을 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final id = _petId, cursor = _nextCursor;
    if (id == null || cursor == null || _loadingMore) return;
    final generation = _requestGeneration;
    setState(() => _loadingMore = true);
    try {
      final page = await _petLogService.list(id, cursor: cursor);
      if (!mounted ||
          generation != _requestGeneration ||
          id != ref.read(petProvider).activePetId) {
        return;
      }
      setState(() {
        _items = [..._items, ...page.items];
        _nextCursor = page.nextCursor;
        _moreError = null;
      });
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _moreError = '기록을 더 불러오지 못했어요.');
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Widget _emptyView(Pet? active) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.photo_album_outlined,
          size: 54,
          color: AppColors.brandMint,
        ),
        const SizedBox(height: 16),
        Text(
          active == null ? '아이를 등록하면 기록을 남길 수 있어요' : '아직 모아둔 기록이 없어요',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          active == null ? '반려동물을 먼저 등록해 주세요.' : '사진과 이야기를 남기면 이곳에 모아볼 수 있어요.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: active == null
              ? () => context.push('/pets/new')
              : () => context.push('/pet-log/new'),
          child: Text(active == null ? '아이 등록하기' : '첫 기록 남기기'),
        ),
      ],
    ),
  );
  Widget _exampleView(Pet? active) {
    final petName = active?.name ?? '우리 아이';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      children: [
        GestureDetector(
          onTap: () {
            final id = _petId;
            if (id != null) context.push('/pet-log/example/$id');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 2.55,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.surfaceSoft),
                  Image.asset(
                    'assets/images/pet_log_example.png',
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: Text(
                      '2026.10.10  15:30',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text('예시 기록'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '$petName와 보낸 산책 시간',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        const Text('카드를 누르면 기록 상세 예시를 볼 수 있어요.'),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _dismissExample,
            child: const Text('예시 기록 삭제'),
          ),
        ),
      ],
    );
  }

  List<Widget> _timelineItems(BuildContext context) {
    final children = <Widget>[];
    int? previousYear;
    for (final item in _items) {
      final year = int.tryParse(item.date.split('-').first);
      if (year != null && year != previousYear) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: 10,
              top: previousYear == null ? 0 : 8,
            ),
            child: Text(
              '$year년',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        previousYear = year;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => context.push('/pet-log/${item.id}', extra: item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 2.55,
                    child: AuthenticatedNetworkImage(
                      url: item.cover?.url,
                      fallback: const ColoredBox(color: AppColors.surfaceSoft),
                      fit: BoxFit.cover,
                      errorBuilder: _photoRetryPlaceholder,
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: Text(
                      '${item.date}  ${item.time.substring(0, min(5, item.time.length))}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return children;
  }

  Future<void> _dismissExample() async {
    final id = _petId;
    if (id == null) return;
    try {
      await _petLogService.dismissExample(id);
      PetLogService.notifyChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예시를 삭제하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(petProvider).activePet;
    final activeId = ref.watch(petProvider).activePetId;
    if (activeId != _petId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(force: true);
      });
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('반려로그'),
        actions: [
          TextButton(
            onPressed: () => context.push('/pet-log/book'),
            child: const Text('기록집'),
          ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
          ? Center(
              child: TextButton(onPressed: _load, child: Text(_error!)),
            )
          : _items.isEmpty
          ? _exampleDismissed
                ? _emptyView(active)
                : _exampleView(active)
          : RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                controller: _scroll,
                children: [
                  if (_error != null)
                    TextButton(
                      onPressed: () => _load(force: true),
                      child: Text(_error!),
                    ),
                  ..._timelineItems(context),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_moreError != null)
                    TextButton(onPressed: _loadMore, child: Text(_moreError!)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: active == null ? null : () => context.push('/pet-log/new'),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class PetLogExampleDetailScreen extends StatelessWidget {
  const PetLogExampleDetailScreen({super.key, required this.petId});
  final String petId;

  Future<void> _delete(BuildContext context) async {
    try {
      await _petLogService.dismissExample(petId);
      PetLogService.notifyChanged();
      if (context.mounted) context.pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예시를 삭제하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('기록 예시')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/pet_log_example.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          alignment: Alignment.centerLeft,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                '예시 화면입니다',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '2026년 10월 10일 · 오후 3:30',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        const Text(
          '산책하다 만난 기분 좋은 순간',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('사진과 짧은 메모를 남기면 우리 아이와 보낸 하루가 이곳에 차곡차곡 모여요.'),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.push('/pet-log/new'),
          child: const Text('내 기록 남기기'),
        ),
        Center(
          child: TextButton(
            onPressed: () => _delete(context),
            child: const Text('예시 기록 삭제'),
          ),
        ),
      ],
    ),
  );
}

class PetLogDetailLoader extends ConsumerStatefulWidget {
  const PetLogDetailLoader({super.key, required this.id});
  final String id;

  @override
  ConsumerState<PetLogDetailLoader> createState() => _PetLogDetailLoaderState();
}

class _PetLogDetailLoaderState extends ConsumerState<PetLogDetailLoader> {
  PetLog? _log;
  String? _petId;
  String? _error;
  bool _loading = false;
  bool _initialLoadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadStarted) return;
    _initialLoadStarted = true;
    _load();
  }

  Future<void> _load() async {
    final petId = ref.read(petProvider).activePetId;
    if (petId == null) {
      setState(() {
        _petId = null;
        _log = null;
        _loading = false;
        _error = '아이를 먼저 등록해 주세요.';
      });
      return;
    }
    if (_loading && _petId == petId) return;
    if (_petId != petId) _log = null;
    _petId = petId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final log = await _petLogService.get(petId, widget.id);
      if (!mounted || ref.read(petProvider).activePetId != petId) return;
      setState(() => _log = log);
    } catch (_) {
      if (mounted && ref.read(petProvider).activePetId == petId) {
        setState(() => _error = '기록을 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && _petId == petId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePetId = ref.watch(petProvider).activePetId;
    if (activePetId != _petId && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    if (_log case final log?) return PetLogDetailScreen(log: log);
    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? '기록을 불러오지 못했어요.'),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('다시 시도')),
                ],
              ),
      ),
    );
  }
}

class PetLogDetailScreen extends StatelessWidget {
  const PetLogDetailScreen({super.key, required this.log});
  final PetLog log;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text(log.date),
      actions: [
        IconButton(
          onPressed: () => context.push('/pet-log/new', extra: log),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          onPressed: () async {
            final ok = await showAppConfirmationSheet(
              context,
              title: '기록을 삭제할까요?',
              message: '삭제한 기록은 다시 복구할 수 없어요.',
              confirmLabel: '삭제',
              confirmKey: const Key('pet-log-delete-confirm'),
            );
            if (ok == true) {
              try {
                await _petLogService.delete(
                  log.petId,
                  log.id,
                  log.version,
                  'petlog-delete-${log.id}-${log.version}',
                );
                PetLogService.notifyChanged();
                if (context.mounted) context.pop(true);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('기록을 삭제하지 못했어요. 다시 시도해 주세요.')),
                  );
                }
              }
            }
          },
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (log.appliedVersion != null && log.version > log.appliedVersion!)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('저장 요청 이후 기록이 다시 수정되어 최신 내용을 표시하고 있어요.'),
          ),
        Text('${log.date} ${log.time.substring(0, min(5, log.time.length))}'),
        const SizedBox(height: 16),
        for (final photo in log.photos)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _PetLogPhotoViewer(
                    photos: log.photos,
                    index: photo.position,
                  ),
                ),
              ),
              child: AuthenticatedNetworkImage(
                url: photo.url,
                fallback: const SizedBox(height: 240),
                fit: BoxFit.contain,
                errorBuilder: _photoRetryPlaceholder,
              ),
            ),
          ),
        if (log.note?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppText(log.note!, fontSize: 16),
          ),
      ],
    ),
  );
}

class _PetLogPhotoViewer extends StatefulWidget {
  const _PetLogPhotoViewer({required this.photos, required this.index});
  final List<PetLogPhoto> photos;
  final int index;
  @override
  State<_PetLogPhotoViewer> createState() => _PetLogPhotoViewerState();
}

class _PetLogPhotoViewerState extends State<_PetLogPhotoViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.index,
  );
  int _index = 0;
  @override
  void initState() {
    super.initState();
    _index = widget.index;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1} / ${widget.photos.length}'),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.photos.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) => Center(
        child: InteractiveViewer(
          child: AuthenticatedNetworkImage(
            url: widget.photos[i].url,
            fallback: const SizedBox.shrink(),
            fit: BoxFit.contain,
            errorBuilder: (context, retry) =>
                _photoRetryPlaceholder(context, retry, dark: true),
          ),
        ),
      ),
    ),
  );
}
