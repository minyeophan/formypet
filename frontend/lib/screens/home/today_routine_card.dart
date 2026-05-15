import 'package:flutter/material.dart';
import '../../models/routine.dart';
import '../../core/record_utils.dart';
import '../../widgets/app_text.dart';

class TodayRoutineCard extends StatelessWidget {
  final List<Routine> routines;
  final Map<String, CompletionStatus> completions;
  final TodayRoutineSummary? summary;
  final String today;
  final void Function(String routineId) onToggle;
  final VoidCallback onViewAll;

  const TodayRoutineCard({
    super.key,
    required this.routines,
    required this.completions,
    required this.summary,
    required this.today,
    required this.onToggle,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final todayRoutines = routines.take(3).toList();

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
              AppText('오늘의 루틴', fontWeight: FontWeight.bold, fontSize: 15),
              if (summary != null)
                AppText('${summary!.done}/${summary!.total}',
                    fontSize: 13, color: Colors.grey),
            ],
          ),
          if (todayRoutines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: AppText('등록된 루틴이 없습니다', color: Colors.grey),
            )
          else
            ...todayRoutines.map((r) {
              final key = '${r.id}:$today';
              final status =
                  completions[key] ?? CompletionStatus.pending;
              final isDone = status == CompletionStatus.completed;
              final type =
                  kQuickTypes.where((t) => t.id == r.typeId).firstOrNull;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(type?.icon ?? Icons.check_circle_outline,
                    color: isDone ? Colors.green : Colors.grey),
                title: AppText(type?.label ?? r.typeId),
                trailing: GestureDetector(
                  onTap: () => onToggle(r.id),
                  child: Icon(
                    isDone ? Icons.check_circle : Icons.circle_outlined,
                    color: isDone ? Colors.green : Colors.grey,
                  ),
                ),
              );
            }),
          TextButton(
            onPressed: onViewAll,
            child: const AppText('전체 루틴 보기', color: Colors.blue),
          ),
        ],
      ),
    );
  }
}
