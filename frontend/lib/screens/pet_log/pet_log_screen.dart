import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
const _exampleRecordedAt = '2026.10.09 19:15';

String _formatTimelineTimestamp(PetLog item) {
  final dateParts = item.date.split('-');
  final date = dateParts.length == 3
      ? '${dateParts[0]}.${dateParts[1]}.${dateParts[2]}'
      : item.date;
  final time = item.time.substring(0, min(5, item.time.length));
  return '$date $time';
}

Widget _photoRetryPlaceholder(
  BuildContext context,
  VoidCallback retry, {
  bool dark = false,
  double height = 220,
}) => Container(
  width: double.infinity,
  height: height,
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
    await _applyPeriod(year: year, month: month, all: all);
  }

  Future<void> _showAllRecords() =>
      _applyPeriod(year: _year, month: null, all: true);

  Future<void> _applyPeriod({
    required int year,
    required int? month,
    required bool all,
  }) async {
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

  Widget _bookEmptyState() {
    if (!_hasAny) {
      return Column(
        children: [
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 44, 20, 28),
              child: Column(
                children: [
                  SvgPicture.asset(
                    'assets/illustrations/pet_log_book_empty.svg',
                    key: const Key('pet-log-book-empty-illustration'),
                    width: 250,
                    height: 172,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '아직 모아둔 기록이 없어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '사진과 이야기를 남기면 이곳에 날짜별로 모아볼 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => context.push('/pet-log/new'),
                      child: const Text('첫 기록 남기기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final periodName = _month == null ? '$_year년' : '$_month월';
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 66, 20, 28),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/illustrations/pet_log_month_empty.svg',
                  key: const Key('pet-log-month-empty-illustration'),
                  width: 148,
                  height: 148,
                ),
                const SizedBox(height: 18),
                Text(
                  '$periodName에는 남긴 기록이 없어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '다른 달의 순간을 찾아보거나\n전체 기록을 한 번에 둘러보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: _changingPeriod ? null : _period,
                    child: const Text('다른 달 보기'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: _changingPeriod ? null : _showAllRecords,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surfaceSoft,
                      foregroundColor: AppColors.text,
                    ),
                    child: const Text('전체 기록 보기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.go('/pet-log'),
          icon: const Icon(Icons.arrow_back, size: 22),
        ),
        titleSpacing: 0,
        title: const Text('기록집'),
        actions: _items.isEmpty
            ? const []
            : [
                IconButton(
                  tooltip: '기록집 공유',
                  onPressed: _items.isEmpty ? null : () {},
                  icon: const Icon(Icons.ios_share_outlined),
                ),
              ],
      ),
      body: Column(
        children: [
          if (_hasAny || _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Material(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _changingPeriod ? null : _period,
                      child: SizedBox(
                        height: 36,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/pet-log'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.text,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('전체 기록'),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(onPressed: _load, child: Text(_error!)),
            ),
          Expanded(
            child: petState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : activePetId == null
                ? const Center(child: Text('아이를 먼저 등록해 주세요.'))
                : _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _bookEmptyState()
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
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/pet-log/${item.id}', extra: item),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                AspectRatio(
                                  key: const Key('pet-log-book-cover'),
                                  aspectRatio: 358 / 160,
                                  child: AuthenticatedNetworkImage(
                                    url: item.cover?.url,
                                    fallback: const ColoredBox(
                                      color: AppColors.surfaceSoft,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: _photoRetryPlaceholder,
                                  ),
                                ),
                                const Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 64,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Color(0xAD000000),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  bottom: 12,
                                  child: Text(
                                    _formatTimelineTimestamp(item),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 5,
                                        ),
                                      ],
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

  Widget _emptyView(Pet? active) {
    if (active == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('아이를 등록하면 기록을 남길 수 있어요'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.push('/pets/new'),
              child: const Text('아이 등록하기'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 84),
          child: Text(
            '2026년',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 23,
              height: 33 / 23,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Center(
          child: SizedBox(
            key: Key('pet-log-empty-illustration'),
            width: 250,
            height: 172,
            child: SvgPicture.asset('assets/illustrations/pet_log_empty.svg'),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '우리 아이의 첫 순간을\n남겨볼까요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 23,
            height: 33 / 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '사진 한 장과 짧은 메모면 충분해요.\n소중한 하루를 차곡차곡 모아보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 22 / 13,
          ),
        ),
      ],
    );
  }

  Widget _exampleView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
            '2026년',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 23,
              height: 33 / 23,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            final id = _petId;
            if (id != null) context.push('/pet-log/example/$id');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 358 / 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.surfaceSoft),
                  Image.asset(
                    'assets/images/pet_log_example.png',
                    fit: BoxFit.cover,
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xAD000000)],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 14,
                    bottom: 12,
                    child: Text(
                      _exampleRecordedAt,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(7)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        child: Text(
                          '예시',
                          style: TextStyle(
                            color: Color(0xFF3C4A42),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

  List<Widget> _timelineItems(BuildContext context) {
    final children = <Widget>[];
    int? previousYear;
    for (final item in _items) {
      final year = int.tryParse(item.date.split('-').first);
      if (year != null && year != previousYear) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: 14,
              top: previousYear == null ? 0 : 8,
            ),
            child: Text(
              '$year년',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 23,
                height: 33 / 23,
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
                    aspectRatio: 358 / 140,
                    child: AuthenticatedNetworkImage(
                      url: item.cover?.url,
                      fallback: const ColoredBox(color: AppColors.surfaceSoft),
                      fit: BoxFit.cover,
                      errorBuilder: _photoRetryPlaceholder,
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xAD000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: Text(
                      _formatTimelineTimestamp(item),
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
        leadingWidth: 54,
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back, size: 22),
        ),
        title: const Text('반려로그'),
        titleSpacing: 0,
        elevation: 0,
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
                : _exampleView()
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
      floatingActionButton: active == null
          ? null
          : FloatingActionButton(
              key: const Key('pet-log-create-fab'),
              heroTag: 'pet-log-create',
              tooltip: _items.isEmpty && _exampleDismissed
                  ? '첫 기록 남기기'
                  : '기록 남기기',
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              onPressed: () => context.push('/pet-log/new'),
              child: const Icon(Icons.edit_outlined),
            ),
    );
  }
}

class PetLogExampleDetailScreen extends StatelessWidget {
  const PetLogExampleDetailScreen({super.key, required this.petId});
  final String petId;

  Future<void> _delete(BuildContext context) async {
    final confirm = await showAppConfirmationSheet(
      context,
      title: '예시 기록을 삭제할까요?',
      message: '예시 기록이 목록에서 사라져요.',
      confirmLabel: '삭제',
      confirmKey: const Key('pet-log-example-delete-confirm'),
    );
    if (confirm != true) return;
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
    appBar: AppBar(
      title: const Text('10월 9일'),
      actions: [
        TextButton(
          onPressed: () => _delete(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.text,
            minimumSize: const Size(52, 44),
          ),
          child: const Text('삭제'),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              const Text(
                '2026년 10월 9일 금요일 19:15',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/pet_log_example.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                '예시 화면입니다.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '사진을 올리고 그날의 이야기를 남겨보세요. 기록이 쌓이면 날짜순으로 다시 볼 수 있어요. 이 예시 기록은 원할 때 삭제할 수 있어요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => context.push('/pet-log/new'),
                child: const Text('내 기록 남기기'),
              ),
            ),
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

  String get _title {
    final parts = log.date.split('-');
    if (parts.length != 3) return log.date;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null) return log.date;
    return '$month월 $day일';
  }

  String get _dateTimeLabel {
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final date = DateTime.tryParse(log.date);
    if (date == null) {
      return '${log.date} ${log.time.substring(0, min(5, log.time.length))}';
    }
    final time = log.time.substring(0, min(5, log.time.length));
    return '${date.year}년 ${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]} $time';
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showAppConfirmationSheet(
      context,
      title: '기록을 삭제할까요?',
      message: '삭제한 기록은 다시 복구할 수 없어요.',
      confirmLabel: '삭제',
      confirmKey: const Key('pet-log-delete-confirm'),
    );
    if (ok != true) return;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text(_title),
      actions: [
        TextButton(
          onPressed: () => context.push('/pet-log/new', extra: log),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.text,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('수정'),
        ),
        PopupMenuButton<String>(
          tooltip: '기록 더보기',
          onSelected: (value) {
            if (value == 'delete') _delete(context);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('기록 삭제')),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageWidth = (constraints.maxWidth - 40)
                  .clamp(0.0, double.infinity)
                  .toDouble();
              return ListView(
                key: const Key('pet-log-detail-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Text(
                    _dateTimeLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (log.appliedVersion != null &&
                      log.version > log.appliedVersion!)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '저장 요청 이후 기록이 다시 수정되어 최신 내용을 표시하고 있어요.',
                      ),
                    ),
                  for (var index = 0; index < log.photos.length; index++) ...[
                    _detailPhoto(context, log.photos[index], index, imageWidth),
                    if (index < log.photos.length - 1)
                      const SizedBox(height: 10),
                  ],
                  if (log.note?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    AppText(log.note!, fontSize: 16),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${log.time.substring(0, min(5, log.time.length))}에 남긴 이야기',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            key: const Key('pet-log-detail-photo-action'),
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  '사진 ${log.photos.length}장',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/pet-log/new', extra: log),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surfaceSoft,
                    foregroundColor: AppColors.text,
                    minimumSize: const Size(107, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('사진 선택'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _detailPhoto(
    BuildContext context,
    PetLogPhoto photo,
    int index,
    double width,
  ) {
    final aspectRatio = photo.width > 0 && photo.height > 0
        ? photo.width / photo.height
        : 1.0;
    final height = aspectRatio > 0 ? width / aspectRatio : width;
    return GestureDetector(
      key: ValueKey('pet-log-photo-${photo.id}'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PetLogPhotoViewer(photos: log.photos, index: index),
        ),
      ),
      child: AuthenticatedNetworkImage(
        url: photo.url,
        width: width,
        height: height,
        fallback: SizedBox(height: height),
        fit: BoxFit.contain,
        errorBuilder: (context, retry) =>
            _photoRetryPlaceholder(context, retry, height: height),
      ),
    );
  }
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
