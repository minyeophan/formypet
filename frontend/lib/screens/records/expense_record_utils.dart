import 'package:intl/intl.dart';

import '../../models/activity_record.dart';

final _wonFormat = NumberFormat('#,###');

List<ActivityRecord> expenseRecords(List<ActivityRecord> records) {
  return records.where((record) => record.typeId == 'expense').toList()
    ..sort(newestExpenseFirst);
}

int newestExpenseFirst(ActivityRecord a, ActivityRecord b) {
  final dateCompare = b.date.compareTo(a.date);
  if (dateCompare != 0) {
    return dateCompare;
  }
  return (b.time ?? '').compareTo(a.time ?? '');
}

num? expenseAmount(ActivityRecord record) {
  final value = record.detail['amount'];
  return value is num ? value : null;
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

String expenseCategory(ActivityRecord record) {
  final category = record.detail['category']?.toString().trim();
  return category == null || category.isEmpty ? '기타' : category;
}

String totalExpenseLabel(List<ActivityRecord> records) {
  final total = records.fold<num>(
    0,
    (sum, record) => sum + (expenseAmount(record) ?? 0),
  );
  return '${_wonFormat.format(total)}원';
}
