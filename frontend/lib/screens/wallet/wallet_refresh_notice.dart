import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pet_provider.dart';
import '../../providers/wallet_expense_provider.dart';
import '../../widgets/app_text.dart';

class WalletRefreshNotice extends ConsumerWidget {
  const WalletRefreshNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletExpenseProvider);
    if (state.refreshWarning == null && state.errorText == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: AppText(state.refreshWarning ?? '지출을 불러오지 못했어요. 새로고침해 주세요.'),
        ),
        TextButton(
          onPressed: state.isLoading || state.isLoadingAll
              ? null
              : () async {
                  final wallet = ref.read(walletExpenseProvider.notifier);
                  final pets = ref.read(petProvider);
                  try {
                    await wallet.loadAllPets(
                      pets.pets.map((pet) => pet.id).toList(),
                    );
                    final petId = state.petId ?? pets.activePetId;
                    if (petId != null) await wallet.loadFirstPage(petId);
                  } catch (_) {
                    // Keep the loaded data and retry notice.
                  }
                },
          child: const Text('새로고침'),
        ),
      ],
    );
  }
}

void showWalletRefreshWarning(BuildContext context, WalletExpenseState state) {
  final warning = state.refreshWarning;
  if (warning != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(warning)));
  }
}
