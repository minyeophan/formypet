import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:frontend/models/wallet_expense.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/services/wallet_expense_service.dart';

void main() {
  test('loadFirstPage loads items and summary', () async {
    final notifier = WalletExpenseNotifier(_FakeWalletExpenseService());

    await notifier.loadFirstPage('pet-1');

    expect(notifier.state.items.map((e) => e.id), ['expense-1']);
    expect(notifier.state.summary.totalAmount, 12000);
    expect(notifier.state.nextCursor, 'next');
    expect(notifier.state.hasMore, isTrue);
  });

  test('create update delete keep wallet state in sync', () async {
    final service = _FakeWalletExpenseService();
    final notifier = WalletExpenseNotifier(service);
    await notifier.loadFirstPage('pet-1');

    await notifier.createExpense('pet-1', {'amount': 5000});
    expect(notifier.state.items.first.id, 'created');
    expect(service.createdBody?['amount'], 5000);

    await notifier.updateExpense('pet-1', 'created', {'itemName': null});
    expect(notifier.state.items.first.itemName, isNull);
    expect(service.updatedBody?['itemName'], isNull);

    await notifier.deleteExpense('pet-1', 'created');
    expect(notifier.state.items.map((e) => e.id), ['expense-1']);
    expect(service.deletedExpenseId, 'created');
  });

  test('loadMore ignores concurrent requests for the same cursor', () async {
    final service = _BlockingWalletExpenseService();
    final notifier = WalletExpenseNotifier(service);
    await notifier.loadFirstPage('pet-1');
    final first = notifier.loadMore('pet-1');
    final second = notifier.loadMore('pet-1');
    await Future<void>.delayed(Duration.zero);
    expect(service.loadMoreCalls, 1);
    service.release();
    await Future.wait([first, second]);
    expect(notifier.state.items.map((e) => e.id), ['expense-1', 'expense-2']);
  });
}

class _FakeWalletExpenseService extends WalletExpenseService {
  Map<String, dynamic>? createdBody;
  Map<String, dynamic>? updatedBody;
  String? deletedExpenseId;

  @override
  Future<WalletExpenseList> listExpenses(
    String petId, {
    String? cursor,
    int? limit,
    String? from,
    String? to,
    String? category,
  }) async => WalletExpenseList(
    items: [_expense('expense-1')],
    nextCursor: 'next',
    hasMore: true,
  );

  @override
  Future<WalletExpenseSummary> getSummary(
    String petId, {
    String? from,
    String? to,
    String? category,
  }) async => const WalletExpenseSummary(
    totalAmount: 12000,
    count: 1,
    currency: 'KRW',
    categories: [],
  );

  @override
  Future<WalletExpense> createExpense(
    String petId,
    Map<String, dynamic> body,
  ) async {
    createdBody = body;
    return _expense('created', amount: body['amount'] as int? ?? 0);
  }

  @override
  Future<WalletExpense> updateExpense(
    String petId,
    String expenseId,
    Map<String, dynamic> body,
  ) async {
    updatedBody = body;
    return _expense(expenseId, itemName: body['itemName'] as String?);
  }

  @override
  Future<void> deleteExpense(String petId, String expenseId) async {
    deletedExpenseId = expenseId;
  }
}

class _BlockingWalletExpenseService extends _FakeWalletExpenseService {
  final _release = Completer<void>();
  int loadMoreCalls = 0;

  @override
  Future<WalletExpenseList> listExpenses(
    String petId, {
    String? cursor,
    int? limit,
    String? from,
    String? to,
    String? category,
  }) async {
    if (cursor == null) return super.listExpenses(petId, cursor: cursor);
    loadMoreCalls++;
    await _release.future;
    return WalletExpenseList(
      items: [_expense('expense-2')],
      nextCursor: null,
      hasMore: false,
    );
  }

  void release() => _release.complete();
}

WalletExpense _expense(
  String id, {
  int amount = 12000,
  String? itemName = 'snack',
}) => WalletExpense(
  id: id,
  petId: 'pet-1',
  expenseDate: '2026-06-12',
  expenseTime: '09:10:00',
  amount: amount,
  currency: 'KRW',
  category: 'snack',
  categoryLabel: '\uAC04\uC2DD',
  itemName: itemName,
);
