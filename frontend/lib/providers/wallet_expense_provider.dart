import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet_expense.dart';
import '../services/wallet_expense_service.dart';

class WalletExpenseState {
  final bool isLoading;
  final bool isMutating;
  final List<WalletExpense> items;
  final WalletExpenseSummary summary;
  final String? nextCursor;
  final bool hasMore;
  final String? errorText;

  const WalletExpenseState({
    required this.isLoading,
    required this.isMutating,
    required this.items,
    required this.summary,
    this.nextCursor,
    required this.hasMore,
    this.errorText,
  });

  factory WalletExpenseState.initial() => WalletExpenseState(
    isLoading: false,
    isMutating: false,
    items: const [],
    summary: WalletExpenseSummary.empty(),
    hasMore: false,
  );

  WalletExpenseState copyWith({
    bool? isLoading,
    bool? isMutating,
    List<WalletExpense>? items,
    WalletExpenseSummary? summary,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    String? errorText,
    bool clearErrorText = false,
  }) => WalletExpenseState(
    isLoading: isLoading ?? this.isLoading,
    isMutating: isMutating ?? this.isMutating,
    items: items ?? this.items,
    summary: summary ?? this.summary,
    nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
    hasMore: hasMore ?? this.hasMore,
    errorText: clearErrorText ? null : (errorText ?? this.errorText),
  );
}

class WalletExpenseNotifier extends StateNotifier<WalletExpenseState> {
  final WalletExpenseService _service;

  WalletExpenseNotifier(this._service) : super(WalletExpenseState.initial());

  Future<void> loadFirstPage(String petId) async {
    state = state.copyWith(isLoading: true, clearErrorText: true);
    try {
      final results = await Future.wait([
        _service.listExpenses(petId),
        _service.getSummary(petId),
      ]);
      final list = results[0] as WalletExpenseList;
      final summary = results[1] as WalletExpenseSummary;
      state = state.copyWith(
        isLoading: false,
        items: list.items,
        summary: summary,
        nextCursor: list.nextCursor,
        clearNextCursor: list.nextCursor == null,
        hasMore: list.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorText: 'wallet load failed');
      rethrow;
    }
  }

  Future<void> loadMore(String petId) async {
    final cursor = state.nextCursor;
    if (!state.hasMore || cursor == null) {
      return;
    }
    final list = await _service.listExpenses(petId, cursor: cursor);
    state = state.copyWith(
      items: [...state.items, ...list.items],
      nextCursor: list.nextCursor,
      clearNextCursor: list.nextCursor == null,
      hasMore: list.hasMore,
    );
  }

  Future<WalletExpense> getExpense(String petId, String expenseId) {
    final existing = state.items
        .where((item) => item.id == expenseId)
        .firstOrNull;
    if (existing != null) {
      return Future.value(existing);
    }
    return _service.getExpense(petId, expenseId);
  }

  Future<WalletExpense> createExpense(
    String petId,
    Map<String, dynamic> body,
  ) async {
    state = state.copyWith(isMutating: true, clearErrorText: true);
    try {
      final created = await _service.createExpense(petId, body);
      final summary = await _service.getSummary(petId);
      state = state.copyWith(
        isMutating: false,
        items: [created, ...state.items],
        summary: summary,
      );
      return created;
    } catch (_) {
      state = state.copyWith(
        isMutating: false,
        errorText: 'wallet mutation failed',
      );
      rethrow;
    }
  }

  Future<WalletExpense> updateExpense(
    String petId,
    String expenseId,
    Map<String, dynamic> body,
  ) async {
    state = state.copyWith(isMutating: true, clearErrorText: true);
    try {
      final updated = await _service.updateExpense(petId, expenseId, body);
      final summary = await _service.getSummary(petId);
      state = state.copyWith(
        isMutating: false,
        items: state.items
            .map((item) => item.id == expenseId ? updated : item)
            .toList(),
        summary: summary,
      );
      return updated;
    } catch (_) {
      state = state.copyWith(
        isMutating: false,
        errorText: 'wallet mutation failed',
      );
      rethrow;
    }
  }

  Future<void> deleteExpense(String petId, String expenseId) async {
    state = state.copyWith(isMutating: true, clearErrorText: true);
    try {
      await _service.deleteExpense(petId, expenseId);
      final summary = await _service.getSummary(petId);
      state = state.copyWith(
        isMutating: false,
        items: state.items.where((item) => item.id != expenseId).toList(),
        summary: summary,
      );
    } catch (_) {
      state = state.copyWith(
        isMutating: false,
        errorText: 'wallet mutation failed',
      );
      rethrow;
    }
  }
}

final walletExpenseServiceProvider = Provider<WalletExpenseService>(
  (_) => WalletExpenseService(),
);

final walletExpenseProvider =
    StateNotifierProvider<WalletExpenseNotifier, WalletExpenseState>(
      (ref) => WalletExpenseNotifier(ref.read(walletExpenseServiceProvider)),
    );
