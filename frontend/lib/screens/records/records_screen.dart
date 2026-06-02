import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../core/pet_colors.dart';
import '../../models/activity_record.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/preparing_toast.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = _dateOnly(now);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petProvider);
    final pet = state.activePet;
    final accent = colorPairForHex(pet?.accentColor ?? '#F4A460');
    final records = state.records;
    final selectedRecords = _recordsForDate(records, _selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: AppInlineHeader(
                  title: pet == null ? '반려기록' : '${pet.name}의 반려기록',
                  onBack: () => _goBack(context),
                  trailing: pet == null
                      ? null
                      : TextButton(
                          onPressed: () => context.push('/records/all'),
                          child: const AppText(
                            '전체 기록',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
            ),
            if (pet == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: AppText(
                    '반려동물을 등록해 주세요.',
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CalendarCard(
                        visibleMonth: _visibleMonth,
                        selectedDate: _selectedDate,
                        recordDates: records.map((r) => r.date).toSet(),
                        accentColor: accent.accent,
                        onPreviousMonth: () {
                          setState(() {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month - 1,
                            );
                          });
                        },
                        onNextMonth: () {
                          setState(() {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                            );
                          });
                        },
                        onSelectDate: (date) {
                          setState(() {
                            _selectedDate = _dateOnly(date);
                            _visibleMonth = DateTime(date.year, date.month);
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      _RecordTypeGrid(
                        onTypeTap: (typeId) {
                          if (typeId == 'meal') {
                            context.push('/records/meal/new');
                            return;
                          }
                          if (_categoryFormTypeIds.contains(typeId)) {
                            context.push('/records/$typeId/new');
                            return;
                          }
                          showPreparingToast(context);
                        },
                      ),
                      const SizedBox(height: 14),
                      _SelectedDateSummary(
                        selectedDate: _selectedDate,
                        records: selectedRecords,
                        onViewAll: () => context.push('/records/all'),
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
}

class AllRecordsScreen extends ConsumerWidget {
  const AllRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = [...ref.watch(petProvider).records]
      ..sort(_newestRecordFirst);
    final grouped = <String, List<ActivityRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.date, () => []).add(record);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: AppInlineHeader(
                  title: '전체 기록',
                  onBack: () => _goBack(context, fallback: '/records'),
                ),
              ),
            ),
            if (records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: _EmptyRecordsPanel(message: '아직 기록이 없어요')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final date = grouped.keys.elementAt(index);
                    final dateRecords = grouped[date]!;
                    return _DateRecordGroup(date: date, records: dateRecords);
                  }, childCount: grouped.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GrowthRecordsScreen extends ConsumerWidget {
  const GrowthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records =
        ref
            .watch(petProvider)
            .records
            .where((record) => record.typeId == 'weight')
            .where((record) => _weightValue(record) != null)
            .toList()
          ..sort(_oldestRecordFirst);

    final newestRecords = [...records]..sort(_newestRecordFirst);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: AppInlineHeader(
                  title: '성장곡선',
                  onBack: () => _goBack(context),
                ),
              ),
            ),
            if (records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: _EmptyRecordsPanel(message: '체중 기록이 없어요')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _GrowthChartCard(records: records),
                    const SizedBox(height: 14),
                    const AppText(
                      '최근 체중 기록',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    const SizedBox(height: 10),
                    for (final record in newestRecords)
                      _WeightRecordRow(record: record),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Set<String> recordDates;
  final Color accentColor;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDate,
    required this.recordDates,
    required this.accentColor,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final calendarDays = getCalendarDays(visibleMonth.year, visibleMonth.month);

    return Container(
      key: const Key('records-calendar'),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CalendarNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPreviousMonth,
              ),
              Expanded(
                child: AppText(
                  DateFormat('yyyy년 M월').format(visibleMonth),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  textAlign: TextAlign.center,
                ),
              ),
              _CalendarNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _weekDays
                .map(
                  (day) => Expanded(
                    child: AppText(
                      day,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.muted,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final date = calendarDays[index];
              final iso = _isoDate(date);
              final inMonth = date.month == visibleMonth.month;
              final isToday = _sameDate(date, DateTime.now());
              final isSelected = _sameDate(date, selectedDate);
              final hasRecord = recordDates.contains(iso);
              return _CalendarDayCell(
                key: Key('records-calendar-day-$iso'),
                date: date,
                isoDate: iso,
                inMonth: inMonth,
                isToday: isToday,
                isSelected: isSelected,
                hasRecord: hasRecord,
                accentColor: accentColor,
                onTap: () => onSelectDate(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalendarNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: AppColors.textSecondary,
      tooltip: '월 이동',
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final String isoDate;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool hasRecord;
  final Color accentColor;
  final VoidCallback onTap;

  const _CalendarDayCell({
    super.key,
    required this.date,
    required this.isoDate,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.hasRecord,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? AppColors.white
        : inMonth
        ? AppColors.text
        : AppColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Container(
            width: 38,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isToday && !isSelected
                  ? Border.all(color: accentColor)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  '${date.day}',
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: textColor,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 5,
                  child: hasRecord
                      ? Container(
                          key: Key('records-date-dot-$isoDate'),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.white : accentColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordTypeGrid extends StatelessWidget {
  final ValueChanged<String> onTypeTap;

  const _RecordTypeGrid({required this.onTypeTap});

  @override
  Widget build(BuildContext context) {
    final visibleTypes = _recordTypes
        .where((type) => type.id != 'expense' && type.id != 'checkup')
        .toList(growable: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibleTypes.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 92,
        ),
        itemBuilder: (context, index) {
          final type = visibleTypes[index];
          return _RecordTypeCard(
            key: Key('records-type-card-${type.id}'),
            type: type,
            onTap: () => onTypeTap(type.id),
          );
        },
      ),
    );
  }
}

class _RecordTypeCard extends StatelessWidget {
  final _RecordTypeConfig type;
  final VoidCallback onTap;

  const _RecordTypeCard({super.key, required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(type.icon, color: type.color, size: 23),
              ),
              const SizedBox(height: 8),
              AppText(
                type.label,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDateSummary extends StatelessWidget {
  final DateTime selectedDate;
  final List<ActivityRecord> records;
  final VoidCallback onViewAll;

  const _SelectedDateSummary({
    required this.selectedDate,
    required this.records,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                key: const Key('records-selected-date'),
                child: AppText(
                  DateFormat('M월 d일 기록').format(selectedDate),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const AppText(
                  '기록 자세히보기',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const _EmptyRecordsPanel(message: '아직 기록이 없어요')
          else
            _SelectedDateRecordList(records: records),
        ],
      ),
    );
  }
}

class _SelectedDateRecordList extends StatelessWidget {
  final List<ActivityRecord> records;

  const _SelectedDateRecordList({required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < records.length; index++) ...[
            _SelectedDateRecordRow(record: records[index]),
            if (index < records.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border,
                indent: 64,
                endIndent: 12,
              ),
          ],
        ],
      ),
    );
  }
}

class _SelectedDateRecordRow extends StatelessWidget {
  final ActivityRecord record;

  const _SelectedDateRecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final type = _typeConfig(record.typeId);
    final icon = record.typeId == 'water'
        ? Icons.water_drop_rounded
        : type.icon;

    return Container(
      key: Key('selected-date-record-${record.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: type.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  type.label,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                AppText(
                  _recordSummary(record),
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppText(
            _timeLabel(record.time),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.muted,
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _DateRecordGroup extends StatelessWidget {
  final String date;
  final List<ActivityRecord> records;

  const _DateRecordGroup({required this.date, required this.records});

  @override
  Widget build(BuildContext context) {
    final sortedRecords = [...records]..sort(_oldestRecordFirst);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: AppText(
              formatDateShort(date),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final record in sortedRecords)
                  _RecordSummaryRow(record: record),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordSummaryRow extends StatelessWidget {
  final ActivityRecord record;

  const _RecordSummaryRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final type = _typeConfig(record.typeId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: AppText(
              _timeLabel(record.time),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.muted,
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 50),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: AppText(
              type.label,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              _recordSummary(record),
              fontSize: 13,
              color: AppColors.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightRecordRow extends StatelessWidget {
  final ActivityRecord record;

  const _WeightRecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final value = _weightValue(record);
    final label = value == null
        ? '체중 기록'
        : '${_numberLabel(value)}${record.detail['unit'] ?? 'kg'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              record.date,
              fontSize: 12,
              color: AppColors.textSecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppText(
            label,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ],
      ),
    );
  }
}

class _GrowthChartCard extends StatelessWidget {
  final List<ActivityRecord> records;

  const _GrowthChartCard({required this.records});

  @override
  Widget build(BuildContext context) {
    final spots = records.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), _weightValue(entry.value)!);
    }).toList();

    return Container(
      key: const Key('records-growth-chart'),
      height: 260,
      padding: const EdgeInsets.fromLTRB(14, 18, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= records.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AppText(
                      records[index].date.substring(5),
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecordsPanel extends StatelessWidget {
  final String message;

  const _EmptyRecordsPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: AppText(
        message,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _RecordTypeConfig {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _RecordTypeConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _recordTypes = [
  _RecordTypeConfig(
    id: 'meal',
    label: '급식',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFFF8A65),
  ),
  _RecordTypeConfig(
    id: 'water',
    label: '음수',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF42A5F5),
  ),
  _RecordTypeConfig(
    id: 'poop',
    label: '배변',
    icon: Icons.pets_rounded,
    color: Color(0xFF8D6E63),
  ),
  _RecordTypeConfig(
    id: 'walk',
    label: '산책',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF66BB6A),
  ),
  _RecordTypeConfig(
    id: 'medicine',
    label: '영양',
    icon: Icons.medication_rounded,
    color: Color(0xFF42A5F5),
  ),
  _RecordTypeConfig(
    id: 'vet',
    label: '병원',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFFEF5350),
  ),
  _RecordTypeConfig(
    id: 'checkup',
    label: '접종',
    icon: Icons.vaccines_rounded,
    color: Color(0xFF5C6BC0),
  ),
  _RecordTypeConfig(
    id: 'weight',
    label: '몸무게',
    icon: Icons.monitor_weight_rounded,
    color: Color(0xFFAB47BC),
  ),
  _RecordTypeConfig(
    id: 'expense',
    label: '지출',
    icon: Icons.payments_rounded,
    color: Color(0xFFFFB74D),
  ),
  _RecordTypeConfig(
    id: 'diary',
    label: '일기',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF78909C),
  ),
  _RecordTypeConfig(
    id: 'etc',
    label: '기타',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF9E9E9E),
  ),
];

const _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

const _categoryFormTypeIds = {
  'water',
  'poop',
  'walk',
  'weight',
  'vet',
  'medicine',
  'diary',
};

List<ActivityRecord> _recordsForDate(
  List<ActivityRecord> records,
  DateTime date,
) {
  final iso = _isoDate(date);
  return records.where((record) => record.date == iso).toList()
    ..sort(_oldestRecordFirst);
}

int _oldestRecordFirst(ActivityRecord a, ActivityRecord b) {
  final dateCompare = a.date.compareTo(b.date);
  if (dateCompare != 0) {
    return dateCompare;
  }
  return (a.time ?? '').compareTo(b.time ?? '');
}

int _newestRecordFirst(ActivityRecord a, ActivityRecord b) {
  final dateCompare = b.date.compareTo(a.date);
  if (dateCompare != 0) {
    return dateCompare;
  }
  return (b.time ?? '').compareTo(a.time ?? '');
}

_RecordTypeConfig _typeConfig(String typeId) {
  return _recordTypes.firstWhere(
    (type) => type.id == typeId,
    orElse: () => _RecordTypeConfig(
      id: typeId,
      label: typeId,
      icon: Icons.notes_rounded,
      color: AppColors.muted,
    ),
  );
}

String _recordSummary(ActivityRecord record) {
  final note = record.note?.trim();
  if (note != null && note.isNotEmpty) {
    return note;
  }
  if (record.typeId == 'weight') {
    final value = _weightValue(record);
    if (value != null) {
      return '${_numberLabel(value)}${record.detail['unit'] ?? 'kg'}';
    }
  }
  return '${_typeConfig(record.typeId).label} 기록';
}

String _timeLabel(String? time) {
  final value = time?.trim();
  if (value == null || value.isEmpty) {
    return '--:--';
  }

  final parsedDateTime = DateTime.tryParse(value);
  if (parsedDateTime != null) {
    return DateFormat('HH:mm').format(parsedDateTime);
  }

  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) {
    return value;
  }
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
}

double? _weightValue(ActivityRecord record) {
  final value = record.detail['value'] ?? record.detail['weight'];
  if (value == null) {
    return null;
  }
  return double.tryParse(value.toString());
}

String _numberLabel(double value) {
  final rounded = value.toStringAsFixed(1);
  return rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

void _goBack(BuildContext context, {String fallback = '/home'}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback);
}
