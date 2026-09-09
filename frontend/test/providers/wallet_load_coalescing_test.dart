import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import '../screens/wallet/wallet_test_api.dart';

void main() {
  test(
    'two screens share one complete load and cache without duplicate HTTP',
    () async {
      final api = WalletTestApi([expenseJson('a', 'p1')]);
      final wallet = WalletExpenseNotifier(WalletExpenseService());
      addTearDown(wallet.dispose);
      final started = Completer<void>();
      final release = Completer<void>();
      api.beforeResponse = (_) async {
        if (!started.isCompleted) started.complete();
        await release.future;
      };
      final a = wallet.ensureAllPets(['p1']);
      await started.future;
      final b = wallet.ensureAllPets(['p1']);
      release.complete();
      await Future.wait([a, b]);
      await wallet.ensureAllPets(['p1']);
      expect(api.requests.where((r) => r.path.endsWith('/expenses')).length, 1);
      expect(wallet.state.expensesByPet['p1']!.single.id, 'a');
    },
  );
}
