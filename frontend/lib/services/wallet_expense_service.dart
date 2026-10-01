import '../core/api_client.dart';
import '../models/wallet_expense.dart';

class WalletExpenseService {
  Future<List<WalletExpense>> listAllExpenses(String petId) async {
    final items = <String, WalletExpense>{};
    final cursors = <String>{};
    String? cursor;
    do {
      final page = await listExpenses(petId, cursor: cursor);
      for (final item in page.items) {
        items[item.id] = item;
      }
      if (!page.hasMore) return items.values.toList();
      cursor = page.nextCursor;
      if (cursor == null || !cursors.add(cursor)) {
        throw StateError('Wallet pagination did not advance');
      }
    } while (true);
  }

  Future<WalletExpenseList> listExpenses(
    String petId, {
    String? cursor,
    int? limit,
    String? from,
    String? to,
    String? category,
  }) async {
    final params = <String, dynamic>{};
    if (cursor != null) params['cursor'] = cursor;
    if (limit != null) params['limit'] = limit;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (category != null) params['category'] = category;

    final res = await dio.get(
      '/api/v1/pets/$petId/wallet/expenses',
      queryParameters: params.isEmpty ? null : params,
    );
    return WalletExpenseList.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<WalletExpenseSummary> getSummary(
    String petId, {
    String? from,
    String? to,
    String? category,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (category != null) params['category'] = category;

    final res = await dio.get(
      '/api/v1/pets/$petId/wallet/expenses/summary',
      queryParameters: params.isEmpty ? null : params,
    );
    return WalletExpenseSummary.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<WalletExpense> getExpense(String petId, String expenseId) async {
    final res = await dio.get('/api/v1/pets/$petId/wallet/expenses/$expenseId');
    return WalletExpense.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<WalletExpense> createExpense(
    String petId,
    Map<String, dynamic> body,
  ) async {
    final res = await dio.post(
      '/api/v1/pets/$petId/wallet/expenses',
      data: body,
    );
    return WalletExpense.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<WalletExpense> updateExpense(
    String petId,
    String expenseId,
    Map<String, dynamic> body,
  ) async {
    final res = await dio.put(
      '/api/v1/pets/$petId/wallet/expenses/$expenseId',
      data: body,
    );
    return WalletExpense.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<void> deleteExpense(String petId, String expenseId) async {
    await dio.delete('/api/v1/pets/$petId/wallet/expenses/$expenseId');
  }
}
