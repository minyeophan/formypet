import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pet_provider.dart';
import '../../models/activity_record.dart';
import '../../core/record_utils.dart';
import '../../core/date_utils.dart';
import '../../widgets/app_text.dart';

class ActivityTab extends ConsumerStatefulWidget {
  const ActivityTab({super.key});

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab> {
  String? _selectedTypeId;
  String? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(petProvider).records;
    final filtered = records.where((r) {
      if (_selectedTypeId != null && r.typeId != _selectedTypeId) return false;
      if (_selectedDate != null && r.date != _selectedDate) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final d = b.date.compareTo(a.date);
        if (d != 0) return d;
        return (b.time ?? '').compareTo(a.time ?? '');
      });

    // Group by date
    final Map<String, List<ActivityRecord>> grouped = {};
    for (final r in filtered) {
      grouped.putIfAbsent(r.date, () => []).add(r);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Type filter chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const AppText('전체'),
                  selected: _selectedTypeId == null,
                  onSelected: (_) =>
                      setState(() => _selectedTypeId = null),
                ),
              ),
              ...kQuickTypes.where((t) => kSupportedTypeIds.contains(t.id)).map((t) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: AppText(t.label),
                      selected: _selectedTypeId == t.id,
                      onSelected: (_) => setState(() =>
                          _selectedTypeId =
                              _selectedTypeId == t.id ? null : t.id),
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          child: dates.isEmpty
              ? const Center(child: AppText('기록이 없습니다', color: Colors.grey))
              : ListView.builder(
                  itemCount: dates.length,
                  itemBuilder: (_, i) {
                    final date = dates[i];
                    final dayRecords = grouped[date]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: AppText(formatDateSection(date),
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        ...dayRecords.map((r) => _RecordTile(record: r)),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final ActivityRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final type =
        kQuickTypes.where((t) => t.id == record.typeId).firstOrNull;
    return ListTile(
      leading: Icon(type?.icon ?? Icons.circle, color: Colors.blue),
      title: AppText(type?.label ?? record.typeId),
      subtitle: record.time != null
          ? AppText(formatTime12h(record.time), fontSize: 12)
          : null,
      trailing: record.note != null
          ? AppText(record.note!, color: Colors.grey, fontSize: 12, maxLines: 1)
          : null,
    );
  }
}
