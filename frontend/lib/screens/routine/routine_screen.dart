import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pet_provider.dart';
import '../../models/routine.dart';
import '../../core/record_utils.dart';
import '../../core/date_utils.dart';
import '../../widgets/app_text.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    final routines = state.routines;
    final completions = state.routineCompletions;
    final today = todayString();

    return Scaffold(
      appBar: AppBar(
        title: const AppText('루틴', fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRoutineDialog(context, ref),
          ),
        ],
      ),
      body: routines.isEmpty
          ? const Center(child: AppText('등록된 루틴이 없습니다', color: Colors.grey))
          : ListView.builder(
              itemCount: routines.length,
              itemBuilder: (_, i) {
                final r = routines[i];
                final key = '${r.id}:$today';
                final status =
                    completions[key] ?? CompletionStatus.pending;
                final type =
                    kQuickTypes.where((t) => t.id == r.typeId).firstOrNull;
                return ListTile(
                  leading:
                      Icon(type?.icon ?? Icons.circle, color: Colors.blue),
                  title: AppText(type?.label ?? r.typeId),
                  subtitle: AppText(
                    '${_repeatLabel(r.repeatType)} • ${r.times.join(', ')}',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => ref
                            .read(petProvider.notifier)
                            .toggleRoutineCompletion(r.id, today),
                        child: Icon(
                          status == CompletionStatus.completed
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: status == CompletionStatus.completed
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                      PopupMenuButton(
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'delete', child: AppText('삭제')),
                        ],
                        onSelected: (v) {
                          if (v == 'delete') {
                            ref
                                .read(petProvider.notifier)
                                .deleteRoutine(r.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _repeatLabel(String repeatType) => switch (repeatType) {
        'daily' => '매일',
        'weekly' => '매주',
        'biweekly' => '2주마다',
        'monthly' => '매월',
        _ => repeatType,
      };
}

Future<void> _showAddRoutineDialog(BuildContext context, WidgetRef ref) async {
  String typeId = 'meal';
  String repeatType = 'daily';
  final timeCtrl = TextEditingController(text: '08:00');

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const AppText('루틴 추가'),
      content: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: typeId,
              items: kQuickTypes
                  .where((t) => kSupportedTypeIds.contains(t.id))
                  .map((t) => DropdownMenuItem(
                        value: t.id,
                        child: AppText(t.label),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => typeId = v!),
            ),
            DropdownButton<String>(
              value: repeatType,
              items: const [
                DropdownMenuItem(value: 'daily', child: AppText('매일')),
                DropdownMenuItem(value: 'weekly', child: AppText('매주')),
                DropdownMenuItem(value: 'biweekly', child: AppText('2주마다')),
                DropdownMenuItem(value: 'monthly', child: AppText('매월')),
              ],
              onChanged: (v) => setState(() => repeatType = v!),
            ),
            TextField(
              controller: timeCtrl,
              decoration:
                  const InputDecoration(labelText: '시간 (HH:MM)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('취소')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final today = todayString();
            await ref.read(petProvider.notifier).addRoutine({
              'typeId': typeId,
              'repeatType': repeatType,
              'times': [timeCtrl.text],
              'days': [],
              'startDate': today,
            });
          },
          child: const AppText('저장'),
        ),
      ],
    ),
  );
}
