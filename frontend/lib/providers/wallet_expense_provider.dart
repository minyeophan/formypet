import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet_expense.dart';
import '../services/wallet_expense_service.dart';
import 'auth_provider.dart';

class WalletExpenseState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isMutating;
  final List<WalletExpense> items;
  final WalletExpenseSummary summary;
  final String? nextCursor;
  final bool hasMore;
  final String? errorText;
  final String? petId;
  final Map<String, List<WalletExpense>> expensesByPet;
  final bool isLoadingAll;
  final String? refreshWarning;
  final int session;

  const WalletExpenseState({
    required this.isLoading,
    this.isLoadingMore = false,
    required this.isMutating,
    required this.items,
    required this.summary,
    this.nextCursor,
    required this.hasMore,
    this.errorText,
    this.petId,
    this.expensesByPet = const {},
    this.isLoadingAll = false,
    this.refreshWarning,
    this.session = 0,
  });

  factory WalletExpenseState.initial() => WalletExpenseState(
    isLoading: false,
    isLoadingMore: false,
    isMutating: false,
    items: const [],
    summary: WalletExpenseSummary.empty(),
    hasMore: false,
  );

  WalletExpenseState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isMutating,
    List<WalletExpense>? items,
    WalletExpenseSummary? summary,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    String? errorText,
    bool clearErrorText = false,
    String? petId,
    Map<String, List<WalletExpense>>? expensesByPet,
    bool? isLoadingAll,
    String? refreshWarning,
    bool clearRefreshWarning = false,
    int? session,
  }) => WalletExpenseState(
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isMutating: isMutating ?? this.isMutating,
    items: items ?? this.items,
    summary: summary ?? this.summary,
    nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
    hasMore: hasMore ?? this.hasMore,
    errorText: clearErrorText ? null : (errorText ?? this.errorText),
    petId: petId ?? this.petId,
    expensesByPet: expensesByPet ?? this.expensesByPet,
    isLoadingAll: isLoadingAll ?? this.isLoadingAll,
    refreshWarning: clearRefreshWarning
        ? null
        : (refreshWarning ?? this.refreshWarning),
    session: session ?? this.session,
  );
}

class WalletExpenseNotifier extends StateNotifier<WalletExpenseState> {
  final WalletExpenseService _service;
  int _session = 0;
  int _pageRequest = 0;
  int _allRequest = 0;
  int _revision = 0;
  final _summaryRevisions = <String, int>{};
  bool _authenticated = true;
  final _changes = <String, Map<String, (int, WalletExpense?)>>{};

  WalletExpenseNotifier(this._service) : super(WalletExpenseState.initial());

  void resetSession({required bool authenticated}) {
    _session++;
    _pageRequest++;
    _allRequest++;
    _authenticated = authenticated;
    _changes.clear();
    _summaryRevisions.clear();
    state = WalletExpenseState.initial().copyWith(session: _session);
  }

  bool _current(int session) => mounted && session == _session;

  List<WalletExpense> _mergeChanges(
    String petId,
    List<WalletExpense> items,
    int revision,
  ) {
    final result = {for (final item in items) item.id: item};
    for (final entry in (_changes[petId] ?? {}).entries) {
      if (entry.value.$1 <= revision) continue;
      final item = entry.value.$2;
      if (item == null) {
        result.remove(entry.key);
      } else {
        result[entry.key] = item;
      }
    }
    return result.values.toList();
  }

  Future<void> loadAllPets(List<String> petIds) async {
    if (!_authenticated) return;
    final session = _session;
    final request = ++_allRequest;
    final revision = _revision;
    state = state.copyWith(isLoadingAll: true, clearErrorText: true);
    try {
      final entries = await Future.wait(
        petIds.map(
          (petId) async =>
              MapEntry(petId, await _service.listAllExpenses(petId)),
        ),
      );
      if (!_current(session) || request != _allRequest) return;
      state = state.copyWith(
        isLoadingAll: false,
        expensesByPet: {
          for (final entry in entries)
            entry.key: _mergeChanges(entry.key, entry.value, revision),
        },
      );
    } catch (_) {
      if (!_current(session) || request != _allRequest) return;
      state = state.copyWith(
        isLoadingAll: false,
        errorText: 'wallet load failed',
      );
      rethrow;
    }
  }

  Future<void> loadFirstPage(String petId) async {
    if (!_authenticated) return;
    final session = _session;
    final request = ++_pageRequest;
    final revision = _revision;
    final summaryRevision = _summaryRevisions[petId] ?? 0;
    state = state.copyWith(
      petId: petId,
      isLoading: true,
      isLoadingMore: false,
      clearErrorText: true,
      items: state.petId == petId ? state.items : [],
      summary: state.petId == petId
          ? state.summary
          : WalletExpenseSummary.empty(),
      hasMore: false,
      clearNextCursor: true,
    );
    try {
      final results = await Future.wait([
        _service.listExpenses(petId),
        _service.getSummary(petId),
      ]);
      final list = results[0] as WalletExpenseList;
      final summary = results[1] as WalletExpenseSummary;
      if (!_current(session) || request != _pageRequest) return;
      state = state.copyWith(
        isLoading: false,
        items: _mergeChanges(petId, list.items, revision),
        summary: summaryRevision == (_summaryRevisions[petId] ?? 0)
            ? summary
            : state.summary,
        clearRefreshWarning: summaryRevision == (_summaryRevisions[petId] ?? 0),
        nextCursor: list.nextCursor,
        clearNextCursor: list.nextCursor == null,
        hasMore: list.hasMore,
      );
    } catch (_) {
      if (!_current(session) || request != _pageRequest) return;
      state = state.copyWith(isLoading: false, errorText: 'wallet load failed');
      rethrow;
    }
  }

  Future<void> loadMore(String petId) async {
    final cursor = state.nextCursor;
    if (!_authenticated ||
        state.petId != petId ||
        !state.hasMore ||
        cursor == null ||
        state.isLoadingMore ||
        state.isLoading) {
      return;
    }
    final session = _session;
    final request = _pageRequest;
    final revision = _revision;
    state = state.copyWith(isLoadingMore: true);
    try {
      final list = await _service.listExpenses(petId, cursor: cursor);
      if (!_current(session) || request != _pageRequest) return;
      state = state.copyWith(
        items: _mergeChanges(petId, [...state.items, ...list.items], revision),
        nextCursor: list.nextCursor,
        clearNextCursor: list.nextCursor == null,
        hasMore: list.hasMore,
      );
    } finally {
      if (_current(session) && request == _pageRequest) {
        state = state.copyWith(isLoadingMore: false);
      }
    }
  }

  Future<WalletExpense> getExpense(String petId, String expenseId) {
    if (!_authenticated) {
      return Future.error(StateError('Wallet session ended'));
    }
    final existing = [
      ...?state.expensesByPet[petId],
      ...state.items,
    ].where((item) => item.id == expenseId && item.petId == petId).firstOrNull;
    if (existing != null) {
      return Future.value(existing);
    }
    final session = _session;
    return _service.getExpense(petId, expenseId).then((expense) {
      if (!_current(session)) throw StateError('Wallet session ended');
      return expense;
    });
  }

  void _commit(String petId, String expenseId, WalletExpense? expense) {
    (_changes[petId] ??= {})[expenseId] = (++_revision, expense);
    _summaryRevisions[petId] = _revision;
    List<WalletExpense> apply(List<WalletExpense> items) => [
      ?expense,
      ...items.where((item) => item.id != expenseId),
    ];
    state = state.copyWith(
      petId: state.petId ?? petId,
      items: state.petId == null || state.petId == petId
          ? apply(state.items)
          : state.items,
      expensesByPet: {
        ...state.expensesByPet,
        if (state.expensesByPet.containsKey(petId))
          petId: apply(state.expensesByPet[petId]!),
      },
    );
  }

  Future<void> _refreshAfterCommit(String petId, int session) async {
    final revision = _summaryRevisions[petId] ?? 0;
    try {
      final summary = await _service.getSummary(petId);
      if (!_current(session) || revision != (_summaryRevisions[petId] ?? 0)) {
        return;
      }
      state = state.copyWith(
        summary: state.petId == petId ? summary : state.summary,
        clearRefreshWarning: true,
      );
    } catch (_) {
      if (!_current(session) || revision != (_summaryRevisions[petId] ?? 0)) {
        return;
      }
      state = state.copyWith(refreshWarning: '변경사항은 저장됐어요. 지출 요약을 새로고침해 주세요.');
    }
  }

  Future<WalletExpense> createExpense(
    String petId,
    Map<String, dynamic> body,
  ) async {
    if (!_authenticated) throw StateError('Wallet session ended');
    final session = _session;
    state = state.copyWith(isMutating: true, clearErrorText: true);
    try {
      final created = await _service.createExpense(petId, body);
      if (!_current(session)) return created;
      _commit(petId, created.id, created);
      await _refreshAfterCommit(petId, session);
      return created;
    } catch (_) {
      if (!_current(session)) rethrow;
      state = state.copyWith(
        isMutating: false,
        errorText: 'wallet mutation failed',
      );
      rethrow;
    } finally {
      if (_current(session)) state = state.copyWith(isMutating: false);
    }
  }

  Future<WalletExpense> updateExpense(
    String petId,
    String expenseId,
    Map<String, dynamic> body,
  ) async {
    if (!_authenticated) throw StateError('Wallet session ended');
    final session = _session;
    state = state.copyWith(isMutating: true, clearErrorText: true);
    try {
      final updated = await _service.updateExpense(petId, expenseId, body);
      if (!_current(session)) return updated;
      _commit(petId, expenseId, updated);
      await _refreshAfterCommit(petId, session);
      return updated;
    } catch (_) {
      if (!_current(session)) rethrow;
      state = state.copyWith(
        isMutating: false,
        errorText: 'wallet mutation failed',
      );
      rethrow;
    } finally {
      if (_current(session)) state = state.copyWith(isMutating: false);
    }
  }

  Future<void> deleteExpense(String petId, String expenseId) async {
    if (!_authenticated) throw StateError('Wallet session ended');
    final session = _session;
    state = state.copyWith(isMutating: true, clearErrorText: true);
    try {
      await _service.deleteExpense(petId, expenseId);
      if (!_current(session)) return;
      _commit(petId, expenseId, null);
      await _refreshAfterCommit(petId, session);
    } catch (_) {
      if (!_current(session)) rethrow;
      state = state.copyWith(
        isMutating: false,
        errorText: 'wallet mutation failed',
      );
      rethrow;
    } finally {
      if (_current(session)) state = state.copyWith(isMutating: false);
    }
  }
}

final walletExpenseServiceProvider = Provider<WalletExpenseService>(
  (_) => WalletExpenseService(),
);

final walletExpenseProvider =
    StateNotifierProvider<WalletExpenseNotifier, WalletExpenseState>((ref) {
      final notifier = WalletExpenseNotifier(
        ref.read(walletExpenseServiceProvider),
      );
      ref.listen(
        authProvider.select(
          (state) => (state.isAuthenticated, state.profile?.id),
        ),
        (previous, next) => notifier.resetSession(authenticated: next.$1),
        fireImmediately: true,
      );
      return notifier;
    });
