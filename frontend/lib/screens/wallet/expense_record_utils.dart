import 'package:intl/intl.dart';

import '../../models/activity_record.dart';

final _wonFormat = NumberFormat('#,###');

const expenseCategoryOptions = [
  ExpenseCategoryOption('food', '사료'),
  ExpenseCategoryOption('snack', '간식'),
  ExpenseCategoryOption('hospital', '병원'),
  ExpenseCategoryOption('medicine', '약'),
  ExpenseCategoryOption('grooming', '미용'),
  ExpenseCategoryOption('supplies', '용품'),
  ExpenseCategoryOption('etc', '기타'),
];

class ExpenseCategoryOption {
  final String key;
  final String label;

  const ExpenseCategoryOption(this.key, this.label);
}

List<ActivityRecord> expenseRecords(List<ActivityRecord> records) {
  return records.where((record) => record.typeId == 'expense').toList()
    ..sort(newestExpenseFirst);
}

int newestExpenseFirst(ActivityRecord a, ActivityRecord b) {
  final dateCompare = b.date.compareTo(a.date);
  if (dateCompare != 0) {
    return dateCompare;
  }
  return normalizeExpenseTime(b.time).compareTo(normalizeExpenseTime(a.time));
}

int? expenseAmount(ActivityRecord record) {
  final value = record.detail['amount'];
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

String expenseAmountLabel(ActivityRecord record) {
  final amount = expenseAmount(record) ?? 0;
  return formatWon(amount);
}

String formatWon(num amount) {
  return '${_wonFormat.format(amount)}원';
}

String expenseTitle(ActivityRecord record) {
  final itemName = record.detail['itemName']?.toString().trim();
  if (itemName != null && itemName.isNotEmpty) {
    return itemName;
  }
  final note = record.note?.trim();
  if (note != null && note.isNotEmpty) {
    return note;
  }
  return '지출 기록';
}

String expenseCategoryLabel(ActivityRecord record) {
  final category = record.detail['category']?.toString().trim();
  return expenseCategoryDisplayLabel(category);
}

String expenseCategoryDisplayLabel(String? category) {
  final value = category?.trim();
  if (value == null || value.isEmpty) {
    return '기타';
  }
  for (final option in expenseCategoryOptions) {
    if (option.key == value) {
      return option.label;
    }
  }
  return value;
}

String totalExpenseLabel(List<ActivityRecord> records) {
  final total = records.fold<int>(
    0,
    (sum, record) => sum + (expenseAmount(record) ?? 0),
  );
  return formatWon(total);
}

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
