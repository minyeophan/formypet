import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/secure_storage.dart';
import 'foreground_notification_service.dart';
import 'push_notification_service.dart';
import 'wallet_budget_service.dart';

class AccountDeletionCleanup {
  static const _queueKey = 'pending_account_deletion_cleanup_v1';
  static final instance = AccountDeletionCleanup(
    actions: {
      'push-session': (_) =>
          PushNotificationService.instance.endSession(disableRemote: false),
      'push-token': (_) =>
          PushNotificationService.instance.clearDeletedAccountToken(),
      'notifications': (_) =>
          ForegroundNotificationService.instance.cancelAll(),
      'credentials': (_) => clearTokens(),
      'push-reference': (_) => clearRegisteredPushToken(),
      'budget': (id) => WalletBudgetService().clearAccount(id),
      'image-cache': (_) => DefaultCacheManager().emptyCache(),
    },
  );
  final Map<String, Future<void> Function(String)> actions;
  final Set<String> _pending = {};
  Future<void> _tail = Future.value();
  AccountDeletionCleanup({required this.actions});

  Future<bool> _serial(Future<bool> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> run(String accountId) => _serial(() => _run(accountId));

  Future<bool> prepare(String accountId) => _serial(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      _pending.addAll(prefs.getStringList(_queueKey) ?? []);
      _pending.add(accountId);
      return await prefs.setStringList(_queueKey, _pending.toList());
    } catch (_) {
      return false;
    }
  });

  Future<bool> cancel(String accountId) => _serial(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      _pending.addAll(prefs.getStringList(_queueKey) ?? []);
      final remaining = _pending.where((id) => id != accountId).toList();
      if (!await prefs.setStringList(_queueKey, remaining)) return false;
      _pending.remove(accountId);
      return true;
    } catch (_) {
      return false;
    }
  });

  Future<bool> _run(String accountId) async {
    _pending.add(accountId);
    SharedPreferences? preferences;
    bool persisted = false;
    try {
      preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      _pending.addAll(preferences.getStringList(_queueKey) ?? []);
      persisted = await preferences.setStringList(_queueKey, _pending.toList());
    } catch (_) {}
    final failed = <String>{};
    for (final action in actions.entries) {
      try {
        await action.value(accountId);
      } catch (_) {
        failed.add(action.key);
      }
    }
    for (final name in failed.toList()) {
      try {
        await actions[name]!(accountId);
        failed.remove(name);
      } catch (_) {}
    }
    if (failed.isNotEmpty || !persisted || preferences == null) return false;
    _pending.remove(accountId);
    try {
      if (await preferences.setStringList(_queueKey, _pending.toList())) {
        return true;
      }
    } catch (_) {}
    _pending.add(accountId);
    return false;
  }

  Future<bool> retryPending() => _serial(() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      _pending.addAll(preferences.getStringList(_queueKey) ?? []);
    } catch (_) {
      return false;
    }
    bool complete = true;
    for (final account in _pending.toList()) {
      if (!await _run(account)) complete = false;
    }
    return complete;
  });
}
