import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/wallet/wallet_expense_utils.dart';
import 'auth_provider.dart';

class WalletQueryState {
  final String? petId;
  final WalletPeriod period;
  final DateTime baseMonth;
  final String? category;
  final DateTime calendarMonth;
  final DateTime selectedDate;

  const WalletQueryState({
    this.petId,
    this.period = WalletPeriod.month,
    required this.baseMonth,
    this.category,
    required this.calendarMonth,
    required this.selectedDate,
  });

  factory WalletQueryState.initial(DateTime now) => WalletQueryState(
    baseMonth: DateTime(now.year, now.month),
    calendarMonth: DateTime(now.year, now.month),
    selectedDate: DateTime(now.year, now.month, now.day),
  );

  WalletQueryState copyWith({
    String? petId,
    bool clearPet = false,
    WalletPeriod? period,
    DateTime? baseMonth,
    String? category,
    bool clearCategory = false,
    DateTime? calendarMonth,
    DateTime? selectedDate,
  }) => WalletQueryState(
    petId: clearPet ? null : petId ?? this.petId,
    period: period ?? this.period,
    baseMonth: baseMonth ?? this.baseMonth,
    category: clearCategory ? null : category ?? this.category,
    calendarMonth: calendarMonth ?? this.calendarMonth,
    selectedDate: selectedDate ?? this.selectedDate,
  );
}

class WalletQueryNotifier extends StateNotifier<WalletQueryState> {
  final DateTime Function() _now;
  (WalletPeriod, DateTime)? _calendarOrigin;
  WalletQueryNotifier({DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(WalletQueryState.initial((now ?? DateTime.now)()));

  void reset() {
    _calendarOrigin = null;
    state = WalletQueryState.initial(_now());
  }

  void setPet(String? id) =>
      state = state.copyWith(petId: id, clearPet: id == null);
  void setCategory(String? value) =>
      state = state.copyWith(category: value, clearCategory: value == null);
  void setPeriod(WalletPeriod value) => state = state.copyWith(period: value);
  void setMonth(DateTime value) =>
      state = state.copyWith(baseMonth: DateTime(value.year, value.month));

  void openCalendar() {
    final origin = (state.period, state.baseMonth);
    if (_calendarOrigin == origin) return;
    _calendarOrigin = origin;
    final now = _now();
    final month = state.period == WalletPeriod.month
        ? state.baseMonth
        : DateTime(now.year, now.month);
    final selected = state.selectedDate;
    state = state.copyWith(
      calendarMonth: month,
      selectedDate: selected.year == month.year && selected.month == month.month
          ? selected
          : (month.year == now.year && month.month == now.month
                ? DateTime(now.year, now.month, now.day)
                : month),
    );
  }

  // Calendar browsing is independent from the main/report period.
  void moveCalendarMonth(int offset) {
    final month = DateTime(
      state.calendarMonth.year,
      state.calendarMonth.month + offset,
    );
    state = state.copyWith(calendarMonth: month, selectedDate: month);
  }

  void selectDate(DateTime date) => state = state.copyWith(
    selectedDate: DateTime(date.year, date.month, date.day),
    calendarMonth: DateTime(date.year, date.month),
  );
  void today() => selectDate(_now());
}

final walletQueryProvider =
    StateNotifierProvider<WalletQueryNotifier, WalletQueryState>((ref) {
      final notifier = WalletQueryNotifier();
      ref.listen(
        authProvider.select((s) => (s.isAuthenticated, s.profile?.id)),
        (previous, next) => notifier.reset(),
      );
      return notifier;
    });
