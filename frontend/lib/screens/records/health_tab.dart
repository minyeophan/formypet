import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pet_provider.dart';
import '../../core/record_utils.dart';
import '../../widgets/app_visual.dart';
import '../../core/date_utils.dart';
import '../../widgets/app_text.dart';

const _healthTypeIds = {'medicine', 'vet'};

class HealthTab extends ConsumerWidget {
  const HealthTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(petProvider).records;
    final healthRecords =
        records.where((r) => _healthTypeIds.contains(r.typeId)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (healthRecords.isEmpty) {
      return const Center(child: AppText('건강 기록이 없습니다', color: Colors.grey));
    }

    return ListView.builder(
      itemCount: healthRecords.length,
      itemBuilder: (_, i) {
        final r = healthRecords[i];
        final type = kQuickTypes.where((t) => t.id == r.typeId).firstOrNull;
        return ListTile(
          leading: AppVisual(
            id: recordTypeVisualId(r.typeId),
            size: 24,
            color: Colors.red,
          ),
          title: AppText(type?.label ?? r.typeId),
          subtitle: AppText(formatDateShort(r.date), fontSize: 12),
          trailing: r.note != null
              ? AppText(r.note!, color: Colors.grey, fontSize: 12, maxLines: 1)
              : null,
        );
      },
    );
  }
}
