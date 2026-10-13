import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_v2_tokens.dart';
import '../../models/pet_log.dart';
import '../../models/pet.dart';
import '../../providers/pet_provider.dart';
import '../../services/pet_log_service.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_ink_well.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_picker_sheet.dart';
import '../../widgets/app_success_toast.dart';
import '../../widgets/preparing_toast.dart';
import '../../services/pet_log_photo_gallery_saver.dart';

final _petLogService = PetLogService();
const _exampleRecordedDate = '2026.10.09';

String _formatTimelineTimestamp(PetLog item) {
  final dateParts = item.date.split('-');
  final date = dateParts.length == 3
      ? '${dateParts[0]}.${dateParts[1]}.${dateParts[2]}'
      : item.date;
  return date;
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
    setState(() {
      _loading = true;
      _loadingMore = false;
    });
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
      if (mounted &&
          generation == _requestGeneration &&
          pet == ref.read(petProvider).activePetId) {
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
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      useSafeArea: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 44),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(
                      height: 24,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          '기간 설정',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(ctx).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Center(
                              child: Text(
                                '$year년',
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Column(
                      children: [
                        for (var row = 0; row < 3; row++) ...[
                          if (row > 0) const SizedBox(height: 8),
                          Row(
                            children: [
                              for (var column = 0; column < 4; column++) ...[
                                if (column > 0) const SizedBox(width: 10),
                                Expanded(
                                  child: _periodMonthButton(
                                    month: row * 4 + column + 1,
                                    selected: month == row * 4 + column + 1,
                                    currentMonth:
                                        year == DateTime.now().year &&
                                        row * 4 + column + 1 ==
                                            DateTime.now().month,
                                    onTap: () =>
                                        set(() => month = row * 4 + column + 1),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('적용'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (apply == false) {
      if (!mounted) return;
      final years = {..._years, year}.toList()..sort((a, b) => b.compareTo(a));
      final selectedYear = await showAppPickerSheet<int>(
        context,
        title: '연도 선택',
        selectedValue: year,
        showDragHandle: true,
        showCloseAction: false,
        showSeparators: false,
        options: [
          for (final availableYear in years)
            AppSelectOption(value: availableYear, label: '$availableYear년'),
        ],
      );
      if (selectedYear == null) return;
      year = selectedYear;
      month = null;
      await _applyPeriod(year: year, month: month, all: false);
      return;
    }
    final all = month == null && _all;
    if (apply != true ||
        (year == initial.$1 && month == initial.$2 && all == initial.$3)) {
      return;
    }
    await _applyPeriod(year: year, month: month, all: all);
  }

  Widget _periodMonthButton({
    required int month,
    required bool selected,
    required bool currentMonth,
    required VoidCallback onTap,
  }) {
    final emphasizeCurrentMonth = currentMonth && !selected;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: selected
            ? AppColors.primary
            : emphasizeCurrentMonth
            ? const Color(0xFFF3F5F4)
            : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key('pet-log-book-month-$month'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: Text(
              '$month월',
              style: TextStyle(
                color: selected ? AppColors.onPrimary : AppColors.text,
                fontSize: 14,
                fontWeight: emphasizeCurrentMonth
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

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

  Future<void> _showAllRecords() =>
      _applyPeriod(year: _year, month: null, all: true);

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
            padding: const EdgeInsets.fromLTRB(20, 84, 20, 28),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/illustrations/pet_log_month_empty.svg',
                  key: const Key('pet-log-month-empty-illustration'),
                  width: 148,
                  height: 148,
                ),
                const SizedBox(height: 4),
                Text(
                  '$periodName에는 남긴 기록이 없어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '다른 달의 순간을 찾아보거나\n전체 기록을 한 번에 둘러보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _changingPeriod ? null : _period,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('다른 달 보기'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _changingPeriod ? null : _showAllRecords,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceSoft,
                      foregroundColor: AppColors.text,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('전체 보기'),
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
      appBar: AppHeader(
        title: '기록집',
        showBackButton: true,
        leadingWidth: 54,
        onBack: () => context.go('/pet-log'),
        actions: _items.isEmpty
            ? const []
            : [
                IconButton(
                  tooltip: '기록집 공유',
                  onPressed: () => showPreparingToast(context),
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
                        width: 182,
                        height: 36,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_month_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
      _loadingMore = false;
      _moreError = null;
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
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
                      _exampleRecordedDate,
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
      appBar: AppHeader(
        title: '반려로그',
        showBackButton: true,
        leadingWidth: 54,
        onBack: () => context.go('/home'),
        actions: [
          TextButton(
            onPressed: () => context.push('/pet-log/book'),
            child: const Text('전체 보기'),
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
          : AppFocusIndicator(
              filled: true,
              shape: const CircleBorder(),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(highlightColor: Colors.transparent),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_items.isEmpty && _exampleDismissed) ...[
                      const AppText(
                        '첫 기록 남기기',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                    ],
                    FloatingActionButton(
                      key: const Key('pet-log-create-fab'),
                      heroTag: 'pet-log-create',
                      tooltip: _items.isEmpty && _exampleDismissed
                          ? '첫 기록 남기기'
                          : '기록 남기기',
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: const CircleBorder(),
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      splashColor: AppColors.primary.withValues(alpha: .10),
                      onPressed: () => context.push('/pet-log/new'),
                      child: const AppIcon(Icons.edit),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class PetLogExampleDetailScreen extends StatelessWidget {
  const PetLogExampleDetailScreen({super.key, required this.petId});
  final String petId;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppHeader(
      title: '10월 9일',
      showBackButton: true,
      leadingWidth: 54,
      onBack: () => context.pop(),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              const SizedBox(height: 70),
              AspectRatio(
                aspectRatio: 1,
                child: Image.asset(
                  'assets/images/pet_log_example.png',
                  fit: BoxFit.contain,
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
                '사진을 올리고 그날의 이야기를 남겨보세요.\n'
                '기록이 쌓이면 날짜순으로 다시 볼 수 있어요.\n\n'
                '이 예시 기록은 원할 때 삭제할 수 있어요.',
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppHeader(
      title: '기록 상세',
      showBackButton: true,
      leadingWidth: 54,
      onBack: () => context.pop(),
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PetLogPhotoSelectScreen(log: log),
                    ),
                  ),
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
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('pet-log-detail-edit'),
                  onPressed: () => context.push('/pet-log/new', extra: log),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(72, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('수정'),
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
    // Figma uses a square slot with BoxFit.contain: the full source image stays
    // visible while each photo occupies the same scroll height.
    final height = width;
    return GestureDetector(
      key: ValueKey('pet-log-photo-${photo.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PetLogPhotoViewer(
            photos: log.photos,
            index: index,
            date: log.date.replaceAll('-', '.'),
          ),
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

class PetLogPhotoSelectScreen extends StatefulWidget {
  const PetLogPhotoSelectScreen({super.key, required this.log});

  final PetLog log;

  @override
  State<PetLogPhotoSelectScreen> createState() =>
      _PetLogPhotoSelectScreenState();
}

class _PetLogPhotoSelectScreenState extends State<PetLogPhotoSelectScreen> {
  final Set<String> _selectedPhotoIds = {};
  bool _saving = false;

  String get _dateLabel {
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final date = DateTime.tryParse(widget.log.date);
    if (date == null) return widget.log.date;
    return '${date.year}년 ${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]}';
  }

  bool get _allSelected =>
      widget.log.photos.isNotEmpty &&
      _selectedPhotoIds.length == widget.log.photos.length;

  void _togglePhoto(String id) {
    setState(() {
      if (!_selectedPhotoIds.add(id)) _selectedPhotoIds.remove(id);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selectedPhotoIds.clear();
      } else {
        _selectedPhotoIds
          ..clear()
          ..addAll(widget.log.photos.map((photo) => photo.id));
      }
    });
  }

  Future<void> _saveSelectedPhotos() async {
    if (_saving || _selectedPhotoIds.isEmpty) return;
    setState(() => _saving = true);
    try {
      final selected = widget.log.photos
          .where((photo) => _selectedPhotoIds.contains(photo.id))
          .toList();
      for (var index = 0; index < selected.length; index++) {
        final photo = selected[index];
        final response = await dio.get<List<int>>(
          photo.url,
          options: Options(
            responseType: ResponseType.bytes,
            extra: const {'_noTransientRetry': true},
          ),
        );
        final contentType = response.headers.value('content-type') ?? '';
        final normalizedContentType = contentType.toLowerCase();
        final extension = normalizedContentType.contains('webp')
            ? 'webp'
            : normalizedContentType.contains('png')
            ? 'png'
            : 'jpg';
        await savePetLogPhotoToGallery(
          Uint8List.fromList(response.data ?? const []),
          'pet-log-${widget.log.date}-${index + 1}.$extension',
          contentType: contentType,
        );
      }
      if (mounted) showAppSuccessToast(context, '저장 완료');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 저장하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedPhotoIds.length;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '사진 선택',
        showBackButton: true,
        leadingWidth: 54,
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF253C39),
              minimumSize: const Size(54, 44),
            ),
            child: const Text('취소', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF697771),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.log.photos.isEmpty ? null : _toggleAll,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF253C39),
                      minimumSize: const Size(76, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      _allSelected ? '전체 해제' : '전체 선택',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('pet-log-photo-select-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                for (
                  var index = 0;
                  index < widget.log.photos.length;
                  index++
                ) ...[
                  _selectablePhoto(widget.log.photos[index], index),
                  if (index < widget.log.photos.length - 1)
                    const SizedBox(height: 10),
                ],
                if (widget.log.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  AppText(
                    widget.log.note!,
                    fontSize: 16,
                    color: const Color(0xFF17232B),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '이야기',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A9691)),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              height: 86,
              padding: const EdgeInsets.fromLTRB(20, 17, 20, 23),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('pet-log-photo-select-save'),
                  onPressed: selectedCount == 0 || _saving
                      ? null
                      : _saveSelectedPhotos,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppV2Tokens.primary,
                    disabledBackgroundColor: const Color(0xFFF5F6F5),
                    disabledForegroundColor: const Color(0xFF8D9992),
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    selectedCount == 0
                        ? '사진을 선택해주세요'
                        : _saving
                        ? '사진 저장 중'
                        : '$selectedCount장 휴대폰에 저장',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectablePhoto(PetLogPhoto photo, int index) {
    final selected = _selectedPhotoIds.contains(photo.id);
    return GestureDetector(
      key: Key('pet-log-select-photo-${photo.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _togglePhoto(photo.id),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AuthenticatedNetworkImage(
              url: photo.url,
              fit: BoxFit.contain,
              fallback: const SizedBox.expand(),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    key: Key('pet-log-photo-selection-indicator-$index'),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? AppV2Tokens.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppV2Tokens.primary
                            : const Color(0xFFB3C5B9),
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLogPhotoViewer extends StatefulWidget {
  const _PetLogPhotoViewer({
    required this.photos,
    required this.index,
    required this.date,
  });
  final List<PetLogPhoto> photos;
  final int index;
  final String date;
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _moveTo(int index) => _controller.animateToPage(
    index,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeInOut,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('pet-log-photo-viewer'),
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        tooltip: '닫기',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
      ),
      title: Text('${_index + 1} / ${widget.photos.length}'),
    ),
    body: Column(
      children: [
        Expanded(
          child: PageView.builder(
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
                      _photoRetryPlaceholder(context, retry),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '이전 사진',
                      onPressed: _index > 0 ? () => _moveTo(_index - 1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${_index + 1} / ${widget.photos.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '다음 사진',
                      onPressed: _index < widget.photos.length - 1
                          ? () => _moveTo(_index + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.date,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
