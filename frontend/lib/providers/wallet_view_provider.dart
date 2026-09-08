import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pet.dart';
import '../models/wallet_expense.dart';
import '../screens/wallet/wallet_expense_utils.dart';
import 'pet_provider.dart';
import 'wallet_expense_provider.dart';
import 'wallet_query_provider.dart';

/// PetState shares this error field with records and routines. Only its known
/// record-load error is safe to ignore with an existing pet list; an ambiguous
/// error may describe a failed pet-list refresh and must remain blocking.
String? walletPetListError(PetState pets) {
  if (pets.pets.isNotEmpty &&
      pets.dataErrorText == '반려동물 기록을 불러오지 못했어요. 다시 시도해 주세요.') {
    return null;
  }
  return pets.dataErrorText;
}

class WalletViewData {
  final List<Pet> pets;
  final WalletQueryState query;
  final WalletAggregation amounts;
  final bool available;
  final bool budgetAvailable;
  final bool loading;
  final String? petError;
  const WalletViewData({
    required this.pets,
    required this.query,
    required this.amounts,
    required this.available,
    required this.budgetAvailable,
    required this.loading,
    required this.petError,
  });
  String? petName(String id) => pets.where((p) => p.id == id).firstOrNull?.name;
}

final walletViewProvider = Provider<WalletViewData>((ref) {
  final pets = ref.watch(petProvider);
  final wallet = ref.watch(walletExpenseProvider);
  final petError = walletPetListError(pets);
  var query = ref.watch(walletQueryProvider);
  if (!pets.isLoading &&
      petError == null &&
      query.petId != null &&
      !pets.pets.any((p) => p.id == query.petId)) {
    query = query.copyWith(clearPet: true);
  }
  final ready = !pets.isLoading && petError == null;
  final selected = pets.pets.where(
    (p) => query.petId == null || p.id == query.petId,
  );
  final all = pets.pets.expand(
    (p) => wallet.expensesByPet[p.id] ?? const <WalletExpense>[],
  );
  return WalletViewData(
    pets: pets.pets,
    query: query,
    amounts: aggregateWalletExpenses(
      all,
      petId: query.petId,
      period: query.period,
      baseMonth: query.baseMonth,
      category: query.category,
    ),
    available:
        ready && selected.every((p) => wallet.expensesByPet.containsKey(p.id)),
    budgetAvailable:
        ready && pets.pets.every((p) => wallet.expensesByPet.containsKey(p.id)),
    loading: pets.isLoading || wallet.isLoadingAll,
    petError: petError,
  );
});

final walletCalendarExpensesProvider = Provider<List<WalletExpense>>((ref) {
  final data = ref.watch(walletViewProvider);
  final wallet = ref.watch(walletExpenseProvider);
  final source = data.pets.expand(
    (p) => wallet.expensesByPet[p.id] ?? const <WalletExpense>[],
  );
  // Include adjacent-month grid cells as well as the focused month.
  return filterWalletExpenses(
    source,
    petId: data.query.petId,
    category: data.query.category,
    period: WalletPeriod.all,
  );
});
