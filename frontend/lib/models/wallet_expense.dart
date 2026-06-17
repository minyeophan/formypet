class WalletExpense {
  final String id;
  final String petId;
  final String expenseDate;
  final String? expenseTime;
  final int amount;
  final String currency;
  final String category;
  final String categoryLabel;
  final String? itemName;
  final String? note;

  const WalletExpense({
    required this.id,
    required this.petId,
    required this.expenseDate,
    this.expenseTime,
    required this.amount,
    required this.currency,
    required this.category,
    required this.categoryLabel,
    this.itemName,
    this.note,
  });

  factory WalletExpense.fromJson(Map<String, dynamic> json) => WalletExpense(
    id: json['id'].toString(),
    petId: json['petId'].toString(),
    expenseDate: json['expenseDate'].toString(),
    expenseTime: json['expenseTime']?.toString(),
    amount: (json['amount'] as num).toInt(),
    currency: json['currency']?.toString() ?? 'KRW',
    category: json['category']?.toString() ?? '',
    categoryLabel: json['categoryLabel']?.toString() ?? '',
    itemName: _nullableTrim(json['itemName']),
    note: _nullableTrim(json['note']),
  );

  WalletExpense copyWith({
    String? id,
    String? petId,
    String? expenseDate,
    String? expenseTime,
    bool clearExpenseTime = false,
    int? amount,
    String? currency,
    String? category,
    String? categoryLabel,
    String? itemName,
    bool clearItemName = false,
    String? note,
    bool clearNote = false,
  }) => WalletExpense(
    id: id ?? this.id,
    petId: petId ?? this.petId,
    expenseDate: expenseDate ?? this.expenseDate,
    expenseTime: clearExpenseTime ? null : (expenseTime ?? this.expenseTime),
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    category: category ?? this.category,
    categoryLabel: categoryLabel ?? this.categoryLabel,
    itemName: clearItemName ? null : (itemName ?? this.itemName),
    note: clearNote ? null : (note ?? this.note),
  );
}

class WalletExpenseList {
  final List<WalletExpense> items;
  final String? nextCursor;
  final bool hasMore;

  const WalletExpenseList({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory WalletExpenseList.fromJson(Map<String, dynamic> json) =>
      WalletExpenseList(
        items: ((json['items'] as List<dynamic>?) ?? const [])
            .map((e) => WalletExpense.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor']?.toString(),
        hasMore: json['hasMore'] == true,
      );
}

class WalletExpenseCategorySummary {
  final String category;
  final String categoryLabel;
  final int amount;
  final int count;

  const WalletExpenseCategorySummary({
    required this.category,
    required this.categoryLabel,
    required this.amount,
    required this.count,
  });

  factory WalletExpenseCategorySummary.fromJson(Map<String, dynamic> json) =>
      WalletExpenseCategorySummary(
        category: json['category']?.toString() ?? '',
        categoryLabel: json['categoryLabel']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class WalletExpenseSummary {
  final int totalAmount;
  final int count;
  final String currency;
  final String? from;
  final String? to;
  final List<WalletExpenseCategorySummary> categories;

  const WalletExpenseSummary({
    required this.totalAmount,
    required this.count,
    required this.currency,
    this.from,
    this.to,
    required this.categories,
  });

  factory WalletExpenseSummary.empty() => const WalletExpenseSummary(
    totalAmount: 0,
    count: 0,
    currency: 'KRW',
    categories: [],
  );

  factory WalletExpenseSummary.fromJson(Map<String, dynamic> json) =>
      WalletExpenseSummary(
        totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'KRW',
        from: json['from']?.toString(),
        to: json['to']?.toString(),
        categories: ((json['categories'] as List<dynamic>?) ?? const [])
            .map(
              (e) => WalletExpenseCategorySummary.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}

String? _nullableTrim(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
