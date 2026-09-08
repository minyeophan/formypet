import 'package:intl/intl.dart';

import '../../models/wallet_expense.dart';

final _wonFormat = NumberFormat('#,###');

const expenseCategoryOptions = [
  ExpenseCategoryOption('food', '\uC0AC\uB8CC'),
  ExpenseCategoryOption('snack', '\uAC04\uC2DD'),
  ExpenseCategoryOption('hospital', '\uBCD1\uC6D0'),
  ExpenseCategoryOption('medicine', '\uC57D'),
  ExpenseCategoryOption('grooming', '\uBBF8\uC6A9'),
  ExpenseCategoryOption('supplies', '\uC6A9\uD488'),
  ExpenseCategoryOption('etc', '\uAE30\uD0C0'),
];

class ExpenseCategoryOption {
  final String key;
  final String label;

  const ExpenseCategoryOption(this.key, this.label);
}

enum WalletPeriod { month, year, all }

WalletPeriod walletPeriodFromValue(String? value) => switch (value) {
  'year' => WalletPeriod.year,
  'all' => WalletPeriod.all,
  _ => WalletPeriod.month,
};

String walletPeriodValue(WalletPeriod period) => switch (period) {
  WalletPeriod.month => 'month',
  WalletPeriod.year => 'year',
  WalletPeriod.all => 'all',
};

List<WalletExpense> filterWalletExpenses(
  Iterable<WalletExpense> source, {
  String? petId,
  String? category,
  WalletPeriod period = WalletPeriod.month,
  DateTime? now,
  DateTime? baseMonth,
}) {
  final today = now ?? DateTime.now();
  final month = baseMonth ?? today;
  return source.where((expense) {
    if (petId != null && expense.petId != petId) return false;
    if (category != null && expense.category != category) return false;
    if (period == WalletPeriod.all) return true;
    final date = walletExpenseDate(expense.expenseDate);
    if (date == null) return false;
    if (period == WalletPeriod.year) return date.year == today.year;
    return date.year == month.year && date.month == month.month;
  }).toList()..sort(newestExpenseFirst);
}

int newestExpenseFirst(WalletExpense a, WalletExpense b) {
  final aDate = walletExpenseDate(a.expenseDate);
  final bDate = walletExpenseDate(b.expenseDate);
  if (aDate == null && bDate != null) return 1;
  if (aDate != null && bDate == null) return -1;
  final dateCompare = b.expenseDate.compareTo(a.expenseDate);
  if (dateCompare != 0) {
    return dateCompare;
  }
  return normalizeExpenseTime(
    b.expenseTime,
  ).compareTo(normalizeExpenseTime(a.expenseTime));
}

DateTime? walletExpenseDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null || DateFormat('yyyy-MM-dd').format(parsed) != value) {
    return null;
  }
  return parsed;
}

class WalletAggregation {
  final List<WalletExpense> periodExpenses;
  final List<WalletExpense> visible;
  final int total;
  final int budgetTotal;
  final Map<String, int> categories;
  const WalletAggregation({
    required this.periodExpenses,
    required this.visible,
    required this.total,
    required this.budgetTotal,
    required this.categories,
  });
}

WalletAggregation aggregateWalletExpenses(
  Iterable<WalletExpense> source, {
  String? petId,
  String? category,
  WalletPeriod period = WalletPeriod.month,
  DateTime? baseMonth,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final items = source.toList();
  final periodExpenses = filterWalletExpenses(
    items,
    petId: petId,
    period: period,
    baseMonth: baseMonth,
    now: today,
  );
  final categories = <String, int>{};
  for (final item in periodExpenses) {
    categories.update(
      item.category,
      (sum) => sum + item.amount,
      ifAbsent: () => item.amount,
    );
  }
  return WalletAggregation(
    periodExpenses: periodExpenses,
    visible: periodExpenses
        .where((e) => category == null || e.category == category)
        .toList(),
    total: periodExpenses.fold(0, (sum, e) => sum + e.amount),
    budgetTotal: filterWalletExpenses(
      items,
      now: today,
    ).fold(0, (sum, e) => sum + e.amount),
    categories: categories,
  );
}

String walletPeriodLabel(
  WalletPeriod period,
  DateTime month, {
  DateTime? now,
}) => switch (period) {
  WalletPeriod.month => '${month.year}년 ${month.month}월',
  WalletPeriod.year => '${(now ?? DateTime.now()).year}년 전체',
  WalletPeriod.all => '전체 기간',
};

String walletExpenseAmountLabel(WalletExpense expense) =>
    formatWon(expense.amount);

String formatWon(num amount) {
  return '${_wonFormat.format(amount)}\uC6D0';
}

String walletExpenseTitle(WalletExpense expense) {
  final itemName = expense.itemName?.trim();
  if (itemName != null && itemName.isNotEmpty) {
    return itemName;
  }
  final note = expense.note?.trim();
  if (note != null && note.isNotEmpty) {
    return note;
  }
  return '\uC9C0\uCD9C \uAE30\uB85D';
}

String walletExpenseCategoryLabel(WalletExpense expense) {
  final label = expense.categoryLabel.trim();
  return label.isEmpty ? expenseCategoryDisplayLabel(expense.category) : label;
}

String expenseCategoryDisplayLabel(String? category) {
  final value = category?.trim();
  if (value == null || value.isEmpty) {
    return '\uAE30\uD0C0';
  }
  for (final option in expenseCategoryOptions) {
    if (option.key == value) {
      return option.label;
    }
  }
  return value;
}

String totalWalletExpenseLabel(List<WalletExpense> expenses) =>
    formatWon(expenses.fold<int>(0, (sum, expense) => sum + expense.amount));

String normalizeExpenseTime(String? time) {
  final value = time?.trim();
  if (value == null || value.isEmpty) {
    return '';
  }

  final parsedDateTime = DateTime.tryParse(value);
  if (parsedDateTime != null) {
    return DateFormat('HH:mm').format(parsedDateTime);
  }

  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) {
    return value;
  }
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
}
