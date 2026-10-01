import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pet_provider.dart';

class RoutineRefreshNotice extends ConsumerWidget {
  const RoutineRefreshNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(
      petProvider.select((state) => state.routineRefreshError),
    );
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(error),
          TextButton(
            onPressed: () async {
              final notifier = ref.read(petProvider.notifier);
              await notifier.retryTodayRoutines();
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
