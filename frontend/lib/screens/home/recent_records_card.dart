import 'package:flutter/material.dart';
import '../../models/activity_record.dart';
import '../../core/record_utils.dart';
import '../../widgets/app_visual.dart';
import '../../core/date_utils.dart';
import '../../widgets/app_text.dart';

class RecentRecordsCard extends StatelessWidget {
  final List<ActivityRecord> records;
  final VoidCallback onViewAll;

  const RecentRecordsCard({
    super.key,
    required this.records,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final today = todayString();
    final todayRecords = records.where((r) => r.date == today).take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText(
                '오늘의 기록',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              TextButton(
                onPressed: onViewAll,
                child: const AppText('전체', color: Colors.blue),
              ),
            ],
          ),
          if (todayRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: AppText('아직 기록이 없습니다', color: Colors.grey),
            )
          else
            ...todayRecords.map((r) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppVisual(
                  id: recordTypeVisualId(r.typeId),
                  size: 24,
                  color: Colors.blue,
                ),
                title: AppText(recordTypeLabel(r.typeId)),
                subtitle: r.time != null
                    ? AppText(formatTime12h(r.time), fontSize: 12)
                    : null,
              );
            }),
        ],
      ),
    );
  }
}
