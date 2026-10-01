import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/wallet_query_provider.dart';
import 'package:frontend/screens/wallet/wallet_expense_utils.dart';
import 'package:frontend/models/wallet_expense.dart';
import 'package:frontend/models/user_profile.dart';

void main() {
  final now = DateTime(2026, 9, 8);
  WalletExpense row(
    String id,
    String pet,
    int amount,
    String date, [
    String category = 'food',
  ]) => WalletExpense(
    id: id,
    petId: pet,
    amount: amount,
    expenseDate: date,
    currency: 'KRW',
    category: category,
    categoryLabel: category,
  );
  final rows = [
    row('a', 'p1', 10000, '2026-09-01'),
    row('b', 'p1', 5000, '2026-09-02', 'hospital'),
    row('c', 'p2', 20000, '2026-09-03'),
    row('old', 'p1', 7000, '2026-08-31'),
    row('last-year', 'p1', 8000, '2025-09-01'),
    row('invalid', 'p1', 999, 'invalid'),
  ];
  test('invalid dates are excluded from bounded periods', () {
    expect(filterWalletExpenses(rows, now: now).map((e) => e.id), [
      'c',
      'b',
      'a',
    ]);
  });
  test('category cannot reduce period total or all-pet monthly budget', () {
    final result = aggregateWalletExpenses(
      rows,
      petId: 'p1',
      category: 'food',
      now: now,
      baseMonth: now,
    );
    expect(result.total, 15000);
    expect(result.budgetTotal, 35000);
    expect(result.visible.map((e) => e.id), ['a']);
    expect(result.categories, {'food': 10000, 'hospital': 5000});
  });
  test('historical month and year/all totals use complete source', () {
    expect(
      aggregateWalletExpenses(
        rows,
        now: now,
        baseMonth: DateTime(2026, 8),
      ).total,
      7000,
    );
    expect(
      aggregateWalletExpenses(rows, now: now, period: WalletPeriod.year).total,
      42000,
    );
    expect(
      aggregateWalletExpenses(rows, now: now, period: WalletPeriod.all).total,
      50999,
    );
  });
  test('calendar month cannot replace a year query', () {
    final query = WalletQueryNotifier(now: () => now);
    addTearDown(query.dispose);
    query.setPet('p2');
    query.setPeriod(WalletPeriod.year);
    query.openCalendar();
    query.moveCalendarMonth(-2);
    expect(query.state.period, WalletPeriod.year);
    expect(query.state.baseMonth, DateTime(2026, 9));
    expect(query.state.calendarMonth, DateTime(2026, 7));
    expect(query.state.petId, 'p2');
  });
  test('month calendar entry uses query month and today resets date only', () {
    final query = WalletQueryNotifier(now: () => now);
    addTearDown(query.dispose);
    query.setMonth(DateTime(2026, 8));
    query.openCalendar();
    expect(query.state.calendarMonth, DateTime(2026, 8));
    query.today();
    expect(query.state.selectedDate, DateTime(2026, 9, 8));
    expect(query.state.baseMonth, DateTime(2026, 8));
  });
  test('logout resets shared query', () {
    final auth = _Auth();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith((ref) => auth)],
    );
    addTearDown(container.dispose);
    container.read(walletQueryProvider.notifier).setPet('p2');
    container.read(walletQueryProvider.notifier).setPeriod(WalletPeriod.all);
    auth.logoutState();
    expect(container.read(walletQueryProvider).petId, isNull);
    expect(container.read(walletQueryProvider).period, WalletPeriod.month);
  });
  test('changing account while authenticated clears query', () {
    final auth = _Auth();
    auth.switchAccount('first');
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith((ref) => auth)],
    );
    addTearDown(container.dispose);
    container.read(walletQueryProvider.notifier).setPet('private-pet');
    container.read(walletQueryProvider.notifier).setCategory('hospital');
    auth.switchAccount('second');
    expect(container.read(walletQueryProvider).petId, isNull);
    expect(container.read(walletQueryProvider).category, isNull);
  });
  test('a fresh app container does not restore prior wallet filters', () {
    final first = ProviderContainer(
      overrides: [authProvider.overrideWith((ref) => _Auth())],
    );
    first.read(walletQueryProvider.notifier).setPet('p2');
    first.read(walletQueryProvider.notifier).setPeriod(WalletPeriod.all);
    first.dispose();
    final second = ProviderContainer(
      overrides: [authProvider.overrideWith((ref) => _Auth())],
    );
    addTearDown(second.dispose);
    expect(second.read(walletQueryProvider).petId, isNull);
    expect(second.read(walletQueryProvider).period, WalletPeriod.month);
  });
}

class _Auth extends AuthNotifier {
  _Auth()
    : super.test(const AuthState(isLoading: false, isAuthenticated: true));
  void logoutState() =>
      state = const AuthState(isLoading: false, isAuthenticated: false);
  void switchAccount(String id) => state = AuthState(
    isLoading: false,
    isAuthenticated: true,
    profile: UserProfile(id: id, email: '$id@test.local', nickname: id),
  );
}
