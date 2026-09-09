import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/wallet/wallet_expense_utils.dart';

/// Device-local budgets, scoped to an authenticated profile and calendar month.
class WalletBudgetService {
  final DateTime Function() _now;
  Future<void> _pending = Future.value();
  WalletBudgetService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static String storageKey(String account, DateTime month) =>
      'wallet_monthly_budget_v2:${Uri.encodeComponent(account)}:'
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<int?> load(String account, DateTime month) => _serial(() async {
    if (account.isEmpty) throw ArgumentError('Missing account');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    const claimKey = 'wallet_monthly_budget_migration_v2';
    var claim = prefs.getString(claimKey);
    final legacy = prefs.getInt('wallet_monthly_budget');
    if (claim == null && legacy != null && legacy > 0) {
      final current = _now();
      // Claim first. Retries can only restore this original account/month.
      claim = jsonEncode({
        'account': account,
        'year': current.year,
        'month': current.month,
        'value': legacy,
      });
      if (!await prefs.setString(claimKey, claim)) {
        await prefs.reload();
        throw StateError('Budget migration claim failed');
      }
    }
    if (claim != null) {
      final migration = jsonDecode(claim) as Map<String, dynamic>;
      if (migration['account'] == account) {
        final key = storageKey(
          account,
          DateTime(migration['year'] as int, migration['month'] as int),
        );
        if (!prefs.containsKey(key)) {
          await _write(prefs, key, migration['value'] as int);
        }
      }
    }
    final value = prefs.getInt(storageKey(account, month));
    return value != null && value > 0 ? value : null;
  });

  Future<void> save(String account, DateTime month, int amount) =>
      _serial(() async {
        if (account.isEmpty || amount <= 0 || amount > walletMaxAmount) {
          throw ArgumentError('Invalid budget');
        }
        final prefs = await SharedPreferences.getInstance();
        await _write(prefs, storageKey(account, month), amount);
      });

  Future<void> _write(SharedPreferences prefs, String key, int amount) async {
    try {
      if (!await prefs.setInt(key, amount)) {
        throw StateError('Budget not saved');
      }
    } catch (_) {
      // The legacy preferences setter updates its cache before persistence.
      await prefs.reload();
      rethrow;
    }
  }
}
