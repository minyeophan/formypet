// Real isolated QA API and Android UI; retain app data with --no-uninstall.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/pet_log_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('petlog photos versioned edit delete cursor and persisted UI', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    final directory = (await getExternalStorageDirectory())!;
    expect(directory.path, contains('com.formypet.frontend.mediatest/'));
    initApiClient('http://127.0.0.1:18083');
    final fixture = File('${directory.path}/petlog-migration.json');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_PETLOG');
    final service = PetLogService();
    Map<String, dynamic> saved;
    String? removable;
    if (existing) {
      saved = jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
    } else {
      await AuthService().register(
        email:
            'petlog-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
        password: List.generate(
          32,
          (_) => Random.secure().nextInt(16).toRadixString(16),
        ).join(),
        nickname: 'JPA 펫로그',
      );
      final pet = await PetService().createPet({
        'name': '펫로그 검증',
        'species': 'dog',
      });
      final picture = img.Image(width: 40, height: 60);
      img.fill(picture, color: img.ColorRgb8(55, 150, 100));
      final bytes = Uint8List.fromList(img.encodePng(picture));
      final firstPhoto = await service.upload(
        pet.id,
        bytes,
        'first.png',
        'petlog-first-photo',
      );
      final secondPhoto = await service.upload(
        pet.id,
        bytes,
        'second.png',
        'petlog-second-photo',
      );
      final at = DateTime(2026, 10, 16, 9, 30);
      final first = await service.create(pet.id, at, 'JPA petlog original', [
        firstPhoto,
      ], 'petlog-first');
      final replay = await service.create(pet.id, at, 'JPA petlog original', [
        firstPhoto,
      ], 'petlog-first');
      expect(replay.id, first.id);
      final second = await service.create(pet.id, at, 'JPA petlog delete', [
        secondPhoto,
      ], 'petlog-second');
      removable = second.id;
      final page = await dio.get(
        '/api/v1/pets/${pet.id}/pet-logs',
        queryParameters: {'limit': 1},
      );
      final data = (page.data as Map)['data'] as Map;
      expect('${(data['items'] as List).single['id']}', second.id);
      final next = await dio.get(
        '/api/v1/pets/${pet.id}/pet-logs',
        queryParameters: {'limit': 1, 'cursor': data['nextCursor']},
      );
      expect(
        '${((next.data as Map)['data']['items'] as List).single['id']}',
        first.id,
      );
      expect(await service.exampleDismissed(pet.id), isTrue);
      saved = {'petId': pet.id, 'id': first.id, 'photoId': firstPhoto};
    }
    final petId = saved['petId'] as String;
    final id = saved['id'] as String;
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
          container.read(authProvider).isAuthenticated &&
          !container.read(petProvider).isLoading &&
          container.read(petProvider).hasOnboarded,
    );
    final router = container.read(routerProvider);
    router.go('/pet-log/$id');
    await _until(
      tester,
      () => find.byKey(const Key('pet-log-detail-edit')).evaluate().isNotEmpty,
    );
    if (!existing) {
      await _tap(tester, find.byKey(const Key('pet-log-detail-edit')));
      await _until(
        tester,
        () => find.byKey(const Key('pet-log-edit-more')).evaluate().isNotEmpty,
      );
      await tester.scrollUntilVisible(
        find.byType(TextField),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await _until(tester, () => find.byType(TextField).evaluate().isNotEmpty);
      await tester.enterText(
        find.byType(TextField).first,
        'JPA petlog persisted',
      );
      await _tap(tester, find.byKey(const Key('pet-log-edit-more')));
      await _tap(tester, find.byKey(const Key('pet-log-edit-menu-save')));
      await _until(
        tester,
        () =>
            find.byKey(const Key('pet-log-detail-edit')).evaluate().isNotEmpty,
      );
      await expectLater(
        service.update(
          petId,
          id,
          DateTime(2026, 10, 16, 9, 30),
          'stale',
          [saved['photoId'] as int],
          0,
          'petlog-stale',
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      router.go('/pet-log/$removable');
      await _tap(tester, find.byKey(const Key('pet-log-detail-edit')));
      await _tap(tester, find.byKey(const Key('pet-log-edit-more')));
      await _tap(tester, find.byKey(const Key('pet-log-edit-menu-delete')));
      await _tap(tester, find.byKey(const Key('pet-log-edit-delete-confirm')));
      await _until(
        tester,
        () => find
            .byKey(const Key('pet-log-edit-delete-confirm'))
            .evaluate()
            .isEmpty,
      );
      await expectLater(
        service.get(petId, removable!),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            404,
          ),
        ),
      );
      await fixture.writeAsString(jsonEncode(saved));
      router.go('/pet-log/$id');
      await _until(
        tester,
        () =>
            find.byKey(const Key('pet-log-detail-edit')).evaluate().isNotEmpty,
      );
    }
    final persisted = await service.get(petId, id);
    expect(persisted.note, 'JPA petlog persisted');
    expect(persisted.version, 1);
    expect(persisted.time, '09:30:00');
    expect(persisted.photos.single.width, 40);
    expect(persisted.photos.single.height, 60);
    expect(find.text('JPA petlog persisted'), findsOneWidget);
    expect(
      (await service.list(petId, year: 2026, month: 10)).items.single.id,
      id,
    );
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'PETLOG_RESTART_VERIFIED' : 'PETLOG_FULL_VERIFIED');
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
  fail('Petlog UI did not become ready');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: .5);
  await tester.pumpAndSettle();
  expect(finder.first.hitTestable(), findsOneWidget);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
