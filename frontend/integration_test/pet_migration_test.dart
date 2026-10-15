// Isolated MuMu package and disposable JPA database only.
// Keep --no-uninstall; repeat with VERIFY_EXISTING_PET=true for persistence.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/media_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/wallet_expense_service.dart';
import 'package:frontend/widgets/authenticated_network_image.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('JPA pet profile CRUD, media and restart persistence', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    expect(
      (await getExternalStorageDirectory())!.path,
      contains('com.formypet.frontend.mediatest/'),
    );
    initApiClient('http://127.0.0.1:18083');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_PET');
    if (!existing) {
      final random = Random.secure();
      await AuthService().register(
        email: 'pet-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
        password: List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join(),
        nickname: 'JPA 펫 검증',
      );
      final pet = await PetService().createPet({
        'name': 'JPA 원본',
        'species': 'dog',
        'birthDate': '2022-03-15',
        'weight': 4.25,
      });
      // Exercise the upload API and image rendering, independently of native picker.
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.orange, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await MediaService().uploadPetPhoto(
        petId: pet.id,
        bytes: bytes!.buffer.asUint8List(),
        filename: 'pet-qa.png',
      );
      image.dispose();
      picture.dispose();
      await WalletExpenseService().createExpense(pet.id, {
        'expenseDate': '2026-10-15',
        'amount': 12000,
        'currency': 'KRW',
        'category': 'food',
        'itemName': '펫 전환 연결 검증',
      });
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FormypetApp(),
      ),
    );
    await _until(
      tester,
      () =>
          !container.read(authProvider).isLoading &&
          !container.read(petProvider).isLoading,
    );
    expect(container.read(authProvider).isAuthenticated, isTrue);
    final pet = (await PetService().getPets()).single;
    expect(pet.weight, 4.25);
    expect(pet.profileImageUrl, isNotNull);
    final router = container.read(routerProvider);
    router.go('/pet/${pet.id}');
    await _until(
      tester,
      () => find.byType(AuthenticatedNetworkImage).evaluate().isNotEmpty,
    );
    final photo = find.byWidgetPredicate(
      (w) => w is AuthenticatedNetworkImage && w.url == pet.profileImageUrl,
    );
    await _until(
      tester,
      () => find
          .descendant(of: photo, matching: find.byType(Image))
          .evaluate()
          .isNotEmpty,
    );

    if (!existing) {
      router.go('/pet/${pet.id}/edit');
      await _until(tester, () => find.byType(TextField).evaluate().isNotEmpty);
      await tester.enterText(find.byType(TextField).first, 'JPA 펫');
      await _hideKeyboard(tester);
      await _tap(tester, find.text('생년월일을 몰라요'));
      await _tap(tester, find.text('저장'));
      await _until(tester, () => find.byTooltip('수정').evaluate().isNotEmpty);

      router.go('/pets/new');
      await _until(tester, () => find.byType(TextField).evaluate().isNotEmpty);
      await tester.enterText(find.byType(TextField).first, 'JPA 삭제 대상');
      await _hideKeyboard(tester);
      await _tap(tester, find.text('등록'));
      await _until(tester, () => find.byTooltip('수정').evaluate().isNotEmpty);
      final added = (await PetService().getPets()).singleWhere(
        (p) => p.name == 'JPA 삭제 대상',
      );
      router.go('/pet/${added.id}');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('삭제'));
      await _tap(tester, find.byKey(const Key('pet-delete-cancel-button')));
      expect((await PetService().getPets()).length, 2);
      await _tap(tester, find.text('삭제'));
      await _tap(tester, find.byKey(const Key('pet-delete-confirm-button')));
      await _until(tester, () => container.read(petProvider).pets.length == 1);
    }
    final saved = (await PetService().getPets()).single;
    expect(saved.id, pet.id);
    expect(saved.name, 'JPA 펫');
    expect(saved.birthDate, isNull);
    expect(saved.weight, 4.25);
    expect(saved.profileImageUrl, pet.profileImageUrl);
    final expenses = await WalletExpenseService().listAllExpenses(saved.id);
    expect(expenses.single.itemName, '펫 전환 연결 검증');
    expect(expenses.single.amount, 12000);
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'PET_RESTART_VERIFIED' : 'PET_UI_VERIFIED');
  });
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Pet UI did not become ready');
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
}
