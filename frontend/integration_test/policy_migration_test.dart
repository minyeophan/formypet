// Uses synthetic TEST FIXTURE ONLY policies on the isolated QA backend.
// Keep --no-uninstall so the reaccept/existing phases use the same account.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/auth/policy_consent_dialog.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/policy_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('policy publication, consent, reacceptance and restart', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    final directory = (await getExternalStorageDirectory())!;
    expect(directory.path, contains('com.formypet.frontend.mediatest/'));
    initApiClient('http://127.0.0.1:18083');
    const stage = String.fromEnvironment(
      'POLICY_STAGE',
      defaultValue: 'signup',
    );
    expect(['signup', 'reaccept', 'existing'], contains(stage));
    final service = PolicyService();
    final auth = AuthService();
    final catalog = await service.catalog();
    expect(catalog['enforcementEnabled'], isTrue);
    final terms = await service.document('terms');
    final privacy = await service.document('privacy');
    for (final document in [terms, privacy]) {
      expect(document['body'], contains('TEST FIXTURE ONLY'));
      expect(document['version'].toString(), startsWith('qa-jpa-policy-'));
    }
    final fixture = File('${directory.path}/policy-migration.json');
    late Map<String, dynamic> saved;
    if (stage == 'signup') {
      Map<String, dynamic>? acceptance;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  acceptance = await collectPolicyAcceptance(
                    context,
                    policyService: service,
                  );
                },
                child: const Text('QA consent'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('QA consent'));
      await _confirm(tester, terms, privacy);
      expect(acceptance?['termsVersion'], terms['version']);
      final random = Random.secure();
      final profile = await auth.register(
        email:
            'policy-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
        password: List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join(),
        nickname: 'JPA 정책 검증',
        policyAcceptance: acceptance,
      );
      await PetService().createPet({'name': '정책 검증', 'species': 'dog'});
      saved = {
        'userId': profile.id,
        'versions': [terms['version']],
        'historyCount': 2,
      };
    } else {
      saved = Map<String, dynamic>.from(
        jsonDecode(await fixture.readAsString()) as Map,
      );
      expect((await auth.getProfile()).id, saved['userId']);
    }
    final status = await service.status();
    expect(status['acceptanceRequired'], stage == 'reaccept');
    if (stage == 'reaccept') {
      await expectLater(
        dio.get('/api/v1/pets'),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'gate status', 403)
              .having(
                (e) => (e.response?.data as Map)['errorCode'],
                'gate code',
                'POLICY_ACCEPTANCE_REQUIRED',
              ),
        ),
      );
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FormypetApp(),
      ),
    );
    await _until(tester, () => !container.read(authProvider).isLoading);
    expect(container.read(authProvider).isAuthenticated, isTrue);
    final router = container.read(routerProvider);
    if (stage == 'reaccept') {
      router.go('/home');
      await _until(
        tester,
        () => find.text('서비스 이용약관 확인').evaluate().isNotEmpty,
      );
      await _tap(tester, find.text('확인하고 계속'));
      await _tap(tester, find.text('취소'));
      expect((await service.status())['acceptanceRequired'], isTrue);
      await _tap(tester, find.text('확인하고 계속'));
      await _confirm(tester, terms, privacy);
      await _until(
        tester,
        () => !container.read(authProvider).policyAcceptanceRequired,
      );
      saved['versions'] = [...saved['versions'] as List, terms['version']];
      saved['historyCount'] = (saved['historyCount'] as int) + 2;
    }
    await _until(tester, () => !container.read(petProvider).isLoading);
    expect((await service.status())['acceptanceRequired'], isFalse);
    expect(unwrap(await dio.get('/api/v1/pets')), isNotEmpty);
    final history = await service.history();
    expect(history, hasLength(saved['historyCount'] as int));
    final expectedVersions = saved['versions'] as List;
    for (final version in expectedVersions) {
      expect(
        history.where((row) => (row as Map)['document_version'] == version),
        hasLength(2),
      );
    }
    await service.accept({
      'termsVersion': terms['version'],
      'termsAccepted': true,
      'age14Confirmed': true,
    });
    expect(await service.history(), history);
    await expectLater(
      service.accept({
        'termsVersion': 'qa-jpa-policy-stale',
        'termsAccepted': true,
        'age14Confirmed': true,
      }),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'stale version',
          409,
        ),
      ),
    );
    router.go('/policy-history');
    await _until(tester, () => find.text('이용약관 동의').evaluate().isNotEmpty);
    expect(find.text('만 14세 이상 확인'), findsWidgets);
    for (final version in expectedVersions) {
      router.go('/policy-history');
      await _until(tester, () => find.text('이용약관 동의').evaluate().isNotEmpty);
      router.go('/policies/terms/$version');
      final doc = await service.document('terms', version: version as String);
      await _until(
        tester,
        () => find.text(doc['body'] as String).evaluate().isNotEmpty,
      );
    }
    router.go('/my/policies/privacy');
    await _until(
      tester,
      () => find.text(privacy['body'] as String).evaluate().isNotEmpty,
    );
    expect(tester.takeException(), isNull);
    if (stage != 'existing') await fixture.writeAsString(jsonEncode(saved));
    debugPrint('POLICY_${stage.toUpperCase()}_VERIFIED');
  });
}

Future<void> _confirm(
  WidgetTester tester,
  Map<String, dynamic> terms,
  Map<String, dynamic> privacy,
) async {
  final submit = find.widgetWithText(FilledButton, '동의하고 계속');
  await _until(tester, () => submit.evaluate().isNotEmpty);
  expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  for (final item in [('이용약관 전문 보기', terms), ('개인정보 처리방침 전문 보기', privacy)]) {
    await _tap(tester, find.text(item.$1));
    expect(find.text(item.$2['title'] as String), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText && (w.data ?? '').contains('TEST FIXTURE ONLY'),
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('닫기'));
  }
  await _tap(tester, find.text('[필수] 이용약관에 동의합니다'));
  expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  await _tap(tester, find.text('[필수] 만 14세 이상입니다'));
  expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  await _tap(tester, submit);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Policy UI did not become ready');
}
