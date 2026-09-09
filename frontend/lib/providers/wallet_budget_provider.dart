import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/wallet/wallet_expense_utils.dart';
import '../services/wallet_budget_service.dart';
import 'auth_provider.dart';
import 'pet_provider.dart';
import 'wallet_expense_provider.dart';
import 'wallet_view_provider.dart';

final walletBudgetServiceProvider = Provider((ref) => WalletBudgetService());

// Include the expense session so an old editor stays invalid after re-login.
final walletBudgetIdentityProvider = Provider<(String?, int)>((ref) {
  final auth = ref.watch(
    authProvider.select((s) => (s.isAuthenticated, s.profile?.id)),
  );
  final session = ref.watch(walletExpenseProvider.select((s) => s.session));
  return (auth.$1 && auth.$2?.isNotEmpty == true ? auth.$2 : null, session);
});

final walletMonthlyBudgetProvider = FutureProvider.autoDispose
    .family<int?, DateTime>((ref, month) {
      final identity = ref.watch(walletBudgetIdentityProvider);
      if (identity.$1 == null) return null;
      return ref.watch(walletBudgetServiceProvider).load(identity.$1!, month);
    });

/// Null means an all-pet total is unavailable, never a partial/zero estimate.
final walletBudgetExpenseProvider = Provider.autoDispose.family<int?, DateTime>(
  (ref, month) {
    final pets = ref.watch(petProvider);
    final wallet = ref.watch(walletExpenseProvider);
    if (pets.isLoading ||
        walletPetListError(pets) != null ||
        !pets.pets.every((p) => wallet.expensesByPet.containsKey(p.id))) {
      return null;
    }
    final expenses = pets.pets.expand((p) => wallet.expensesByPet[p.id]!);
    return filterWalletExpenses(
      expenses,
      baseMonth: month,
    ).fold<int>(0, (sum, expense) => sum + expense.amount);
  },
);
