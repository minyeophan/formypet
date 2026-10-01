import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/wallet_expense_provider.dart';
import 'package:frontend/services/wallet_expense_service.dart';

import '../screens/wallet/wallet_test_api.dart';

void main() {
  test(
    'pet A mutation does not discard pet B in-flight first-page summary',
    () async {
      final api = WalletTestApi([
        expenseJson('a', 'p1'),
        expenseJson('b', 'p2', amount: 7000),
      ]);
      final wallet = WalletExpenseNotifier(WalletExpenseService());
      addTearDown(wallet.dispose);
      final requested = Completer<void>();
      final release = Completer<void>();
      api.beforeResponse = (options) async {
        if (options.path == '/api/v1/pets/p2/wallet/expenses/summary') {
          requested.complete();
          await release.future;
        }
      };
      final loading = wallet.loadFirstPage('p2');
      await requested.future;
      await wallet.updateExpense('p1', 'a', {'amount': 3000});
      release.complete();
      await loading;
      expect(wallet.state.petId, 'p2');
      expect(wallet.state.items.single.amount, 7000);
      expect(wallet.state.summary.totalAmount, 7000);
      expect(wallet.state.summary.count, 1);
      expect(wallet.state.refreshWarning, isNull);
    },
  );

  test('pet A mutation does not discard pet B post-commit summary', () async {
    final api = WalletTestApi([expenseJson('a', 'p1'), expenseJson('b', 'p2')]);
    final wallet = WalletExpenseNotifier(WalletExpenseService());
    addTearDown(wallet.dispose);
    await wallet.loadFirstPage('p2');
    final requested = Completer<void>();
    final release = Completer<void>();
    api.beforeResponse = (options) async {
      if (options.path == '/api/v1/pets/p2/wallet/expenses/summary') {
        requested.complete();
        await release.future;
      }
    };
    final saving = wallet.updateExpense('p2', 'b', {'amount': 7000});
    await requested.future;
    await wallet.updateExpense('p1', 'a', {'amount': 3000});
    release.complete();
    await saving;
    expect(wallet.state.items.single.amount, 7000);
    expect(wallet.state.summary.totalAmount, 7000);
  });

  test(
    'account switch clears wallet caches and ignores the previous account response',
    () async {
      final api = WalletTestApi([expenseJson('a', 'p1')]);
      final account = _Account();
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith((ref) => account)],
      );
      addTearDown(container.dispose);
      final wallet = container.read(walletExpenseProvider.notifier);
      await wallet.loadFirstPage('p1');
      await wallet.loadAllPets(['p1']);
      final requested = Completer<void>();
      final release = Completer<void>();
      api.beforeResponse = (options) async {
        if (options.path.endsWith('/expenses')) {
          requested.complete();
          await release.future;
        }
      };
      final loading = wallet.loadAllPets(['p1']);
      await requested.future;
      account.switchTo('b');
      expect(container.read(walletExpenseProvider).items, isEmpty);
      expect(container.read(walletExpenseProvider).expensesByPet, isEmpty);
      release.complete();
      await loading;
      expect(container.read(walletExpenseProvider).expensesByPet, isEmpty);
    },
  );

  test(
    'late mutation success from an ended session cannot repopulate caches',
    () async {
      final api = WalletTestApi([]);
      final wallet = WalletExpenseNotifier(WalletExpenseService());
      addTearDown(wallet.dispose);
      final requested = Completer<void>();
      final release = Completer<void>();
      api.beforeResponse = (options) async {
        if (options.method == 'POST') {
          requested.complete();
          await release.future;
        }
      };
      final saving = wallet.createExpense('p1', {'amount': 7000});
      await requested.future;
      wallet.resetSession(authenticated: false);
      release.complete();
      await saving;
      expect(wallet.state.items, isEmpty);
      expect(wallet.state.expensesByPet, isEmpty);
      expect(wallet.state.refreshWarning, isNull);
      expect(api.requests.where((r) => r.path.endsWith('/summary')), isEmpty);
      await expectLater(wallet.createExpense('p1', {}), throwsStateError);
    },
  );

  test(
    'late complete page loading preserves committed updates and deletes',
    () async {
      final api = WalletTestApi([
        expenseJson('updated', 'p1'),
        expenseJson('deleted', 'p1'),
      ]);
      final wallet = WalletExpenseNotifier(WalletExpenseService());
      addTearDown(wallet.dispose);
      await wallet.loadAllPets(['p1']);
      final requested = Completer<void>();
      final release = Completer<void>();
      api.beforeResponse = (options) async {
        if (options.path.endsWith('/expenses') && options.method == 'GET') {
          requested.complete();
          await release.future;
        }
      };
      final loading = wallet.loadAllPets(['p1']);
      await requested.future;
      await wallet.updateExpense('p1', 'updated', {'amount': 7000});
      await wallet.deleteExpense('p1', 'deleted');
      release.complete();
      await loading;
      expect(wallet.state.expensesByPet['p1']!.single.id, 'updated');
      expect(wallet.state.expensesByPet['p1']!.single.amount, 7000);
    },
  );

  test(
    'a rejected mutation retains previous data and reports failure',
    () async {
      final api = WalletTestApi([expenseJson('old', 'p1')]);
      final wallet = WalletExpenseNotifier(WalletExpenseService());
      addTearDown(wallet.dispose);
      await wallet.loadFirstPage('p1');
      api.mutationFails = true;
      await expectLater(
        wallet.updateExpense('p1', 'old', {'amount': 7000}),
        throwsException,
      );
      expect(wallet.state.items.single.amount, 1000);
      expect(wallet.state.errorText, isNotNull);
      expect(wallet.state.refreshWarning, isNull);
      expect(wallet.state.isMutating, isFalse);
    },
  );

  for (final operation in ['create', 'update', 'delete']) {
    test('$operation remains committed when summary refresh fails', () async {
      final api = WalletTestApi([expenseJson('old', 'p1')]);
      final notifier = WalletExpenseNotifier(WalletExpenseService());
      addTearDown(notifier.dispose);
      await notifier.loadFirstPage('p1');
      api.summaryFails = true;
      Object? failure;
      try {
        switch (operation) {
          case 'create':
            await notifier.createExpense('p1', {'amount': 7000});
          case 'update':
            await notifier.updateExpense('p1', 'old', {'amount': 7000});
          case 'delete':
            await notifier.deleteExpense('p1', 'old');
        }
      } catch (error) {
        failure = error;
      }
      expect(
        failure,
        isNull,
        reason: 'The server already committed the mutation',
      );
      expect(notifier.state.isMutating, isFalse);
      expect(notifier.state.items.map((e) => e.amount), switch (operation) {
        'create' => [7000, 1000],
        'update' => [7000],
        _ => <int>[],
      });
    });
  }

  test('a late first page cannot undo a successful update', () async {
    final api = WalletTestApi([expenseJson('old', 'p1')]);
    final notifier = WalletExpenseNotifier(WalletExpenseService());
    addTearDown(notifier.dispose);
    await notifier.loadFirstPage('p1');
    final requested = Completer<void>();
    final release = Completer<void>();
    api.beforeResponse = (options) async {
      if (options.method == 'GET' && options.path.endsWith('/expenses')) {
        requested.complete();
        await release.future;
      }
    };
    final loading = notifier.loadFirstPage('p1');
    await requested.future;
    await notifier.updateExpense('p1', 'old', {'amount': 7000});
    release.complete();
    await loading;
    expect(notifier.state.items.single.amount, 7000);
    expect(notifier.state.summary.totalAmount, 7000);
  });

  test('late pet A response cannot replace selected pet B', () async {
    final api = WalletTestApi([expenseJson('a', 'p1'), expenseJson('b', 'p2')]);
    final notifier = WalletExpenseNotifier(WalletExpenseService());
    addTearDown(notifier.dispose);
    final requested = Completer<void>();
    final release = Completer<void>();
    api.beforeResponse = (options) async {
      if (options.path == '/api/v1/pets/p1/wallet/expenses') {
        requested.complete();
        await release.future;
      }
    };
    final loading = notifier.loadFirstPage('p1');
    await requested.future;
    await notifier.loadFirstPage('p2');
    release.complete();
    await loading;
    expect(notifier.state.items.single.id, 'b');
  });

  test('detail cache lookup also checks the expense owner', () async {
    WalletTestApi([
      expenseJson('same', 'p1'),
      expenseJson('same', 'p2', amount: 7000),
    ]);
    final notifier = WalletExpenseNotifier(WalletExpenseService());
    addTearDown(notifier.dispose);
    await notifier.loadFirstPage('p1');
    final expense = await notifier.getExpense('p2', 'same');
    expect(expense.petId, 'p2');
    expect(expense.amount, 7000);
  });
}

class _Account extends AuthNotifier {
  _Account() : super.test(_state('a'));
  void switchTo(String id) => state = _state(id);
  static AuthState _state(String id) => AuthState(
    isLoading: false,
    isAuthenticated: true,
    profile: UserProfile(id: id, email: '$id@test.invalid', nickname: id),
  );
}
