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

int newestExpenseFirst(WalletExpense a, WalletExpense b) {
  final dateCompare = b.expenseDate.compareTo(a.expenseDate);
  if (dateCompare != 0) {
    return dateCompare;
  }
  return normalizeExpenseTime(
    b.expenseTime,
  ).compareTo(normalizeExpenseTime(a.expenseTime));
}

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
