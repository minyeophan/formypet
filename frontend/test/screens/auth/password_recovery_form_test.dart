import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/auth/password_recovery_form.dart';
import 'package:frontend/services/password_recovery_service.dart';

void main() {
  testWidgets(
    'background resume preserves flow and leaving ignores pending confirmation',
    (tester) async {
      final service = DelayedConfirmation();
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PasswordRecoveryForm(
                service: service,
                onClose: () {},
                onCompleted: () => completed = true,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('recovery-email')),
        'user@example.com',
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('recovery-code')), findsOneWidget);
      expect(find.textContaining('남은 시간:'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('recovery-code')), '123456');
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recovery-password')),
        'NewPassword123!',
      );
      await tester.enterText(
        find.byKey(const Key('recovery-confirmation')),
        'NewPassword123!',
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      service.completion.complete();
      await tester.pump();
      expect(completed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'lost verification and confirmation responses reuse operation ids',
    (tester) async {
      final service = RetryRecovery();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PasswordRecoveryForm(
                service: service,
                onClose: () {},
                onCompleted: () {},
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('recovery-email')),
        'user@example.com',
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('recovery-resend')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('recovery-code')), '123456');
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery-code')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('recovery-code')), '12345');
      await tester.enterText(find.byKey(const Key('recovery-code')), '123456');
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      expect(service.verifyIds.toSet(), hasLength(1));
      await tester.enterText(
        find.byKey(const Key('recovery-password')),
        'NewPassword123!',
      );
      await tester.enterText(
        find.byKey(const Key('recovery-confirmation')),
        'NewPassword123!',
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recovery-password')),
        'NewPassword123',
      );
      await tester.enterText(
        find.byKey(const Key('recovery-password')),
        'NewPassword123!',
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      expect(service.confirmIds.toSet(), hasLength(1));
      expect(find.text('로그인으로 돌아가기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('restart ignores pending verification and clears code', (
    tester,
  ) async {
    final service = DelayedVerification();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PasswordRecoveryForm(
              service: service,
              onClose: () {},
              onCompleted: () {},
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('recovery-email')),
      'user@example.com',
    );
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('recovery-code')), '123456');
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pump();
    await tester.tap(find.text('이메일 변경 / 다시 시작'));
    await tester.pump();
    service.verification.complete(
      RecoveryVerified(
        'late-token',
        DateTime.now().add(const Duration(minutes: 5)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-email')), findsOneWidget);
    expect(find.byKey(const Key('recovery-password')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'email code and password flow returns to login without authentication',
    (tester) async {
      final service = FakeRecovery();
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PasswordRecoveryForm(
                service: service,
                onClose: () {},
                onCompleted: () {
                  finished = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('recovery-email')),
        'user@example.com',
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery-code')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('recovery-code')), '123456');
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recovery-password')),
        'NewPassword123!',
      );
      await tester.enterText(
        find.byKey(const Key('recovery-confirmation')),
        'mismatch',
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pump();
      expect(service.confirmations, 0);
      await tester.enterText(
        find.byKey(const Key('recovery-confirmation')),
        'NewPassword123!',
      );
      await tester.tap(find.byKey(const Key('recovery-submit')));
      await tester.pumpAndSettle();
      expect(service.confirmations, 1);
      expect(finished, isFalse);
      await tester.tap(find.text('로그인으로 돌아가기'));
      expect(finished, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('leaving ignores a delayed request response', (tester) async {
    final service = FakeRecovery()..pending = Completer<RecoveryChallenge>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordRecoveryForm(
            service: service,
            onClose: () {},
            onCompleted: () {},
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('recovery-email')),
      'user@example.com',
    );
    await tester.tap(find.byKey(const Key('recovery-submit')));
    await tester.pumpWidget(const SizedBox());
    service.pending!.complete(service.challenge);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class FakeRecovery extends PasswordRecoveryService {
  Completer<RecoveryChallenge>? pending;
  int confirmations = 0;
  final challenge = RecoveryChallenge(
    'challenge',
    DateTime.now().add(const Duration(minutes: 10)),
    DateTime.now().add(const Duration(seconds: 60)),
  );
  @override
  Future<RecoveryChallenge> request(String email) async =>
      pending == null ? challenge : pending!.future;
  @override
  Future<RecoveryVerified> verify(
    String challengeId,
    String code,
    String requestId,
  ) async {
    return RecoveryVerified(
      'token',
      DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<void> confirm(String token, String password, String requestId) async {
    confirmations++;
  }
}

class RetryRecovery extends FakeRecovery {
  final verifyIds = <String>[];
  final confirmIds = <String>[];
  @override
  Future<RecoveryVerified> verify(
    String challengeId,
    String code,
    String requestId,
  ) async {
    verifyIds.add(requestId);
    if (verifyIds.length == 1) throw Exception('lost response');
    return super.verify(challengeId, code, requestId);
  }

  @override
  Future<void> confirm(String token, String password, String requestId) async {
    confirmIds.add(requestId);
    if (confirmIds.length == 1) throw Exception('lost response');
    return super.confirm(token, password, requestId);
  }
}

class DelayedVerification extends FakeRecovery {
  final verification = Completer<RecoveryVerified>();
  @override
  Future<RecoveryVerified> verify(
    String challengeId,
    String code,
    String requestId,
  ) => verification.future;
}

class DelayedConfirmation extends FakeRecovery {
  final completion = Completer<void>();
  @override
  Future<void> confirm(String token, String password, String requestId) =>
      completion.future;
}
