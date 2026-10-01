import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../providers/pet_provider.dart';
import 'app_text.dart';

/// Distinguishes a failed pet-data request from a genuinely empty history.
class PetDataStatus extends ConsumerWidget {
  const PetDataStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petProvider);
    if (state.isLoading) return const LinearProgressIndicator();
    final error = state.dataErrorText;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AppText(
            error,
            color: AppColors.textSecondary,
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(petProvider.notifier).retryDataLoad();
              } catch (_) {
                // The provider retains a retryable error on another failure.
              }
            },
            child: const AppText('다시 시도', color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
