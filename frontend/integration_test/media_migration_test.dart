// Real QA backend + isolated Android app. Always run with --no-uninstall.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/main.dart' show FormypetApp;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/services/media_service.dart';
import 'package:frontend/services/pet_log_service.dart';
import 'package:frontend/services/pet_service.dart';
import 'package:frontend/services/record_service.dart';
import 'package:frontend/widgets/authenticated_network_image.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('JPA media actual uploads, replacements, deletion and restart', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('ISOLATED_MEDIA_TEST'), isTrue);
    expect(const bool.fromEnvironment('ALLOW_ISOLATED_QA_WRITES'), isTrue);
    final directory = (await getExternalStorageDirectory())!;
    expect(directory.path, contains('com.formypet.frontend.mediatest/'));
    initApiClient('http://127.0.0.1:18083');
    const existing = bool.fromEnvironment('VERIFY_EXISTING_MEDIA');
    final fixture = File('${directory.path}/media-migration.json');
    final auth = AuthService();
    final logs = PetLogService();
    final records = RecordService();
    final community = CommunityService();
    late Map<String, dynamic> data;
    if (!existing) {
      final random = Random.secure();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      await auth.register(
        email: 'media-$stamp@example.invalid',
        password: List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join(),
        nickname: 'JPA 미디어 검증',
      );
      final pet = await PetService().createPet({
        'name': '미디어 검증',
        'species': 'dog',
      });
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(40, 30);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      // Upload through the real app services; no gallery-picker mocking or mock HTTP.
      final first = await auth.uploadProfileImage(
        bytes: bytes,
        filename: 'first.png',
      );
      final replacement = await auth.uploadProfileImage(
        bytes: bytes,
        filename: 'replacement.png',
      );
      expect(replacement.profileImageUrl, isNot(first.profileImageUrl));
      await _missing(first.profileImageUrl!);
      final petUrl = await MediaService().uploadPetPhoto(
        petId: pet.id,
        bytes: bytes,
        filename: 'pet.png',
      );
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final record = await records.createRecordWithMediaBytes(
        petId: pet.id,
        body: {'typeId': 'meal', 'date': date, 'note': '미디어 사진 기록'},
        files: [RecordMediaUpload(bytes: bytes, filename: 'record.png')],
      );
      final removableRecord = await records.createRecordWithMediaBytes(
        petId: pet.id,
        body: {'typeId': 'meal', 'date': date},
        files: [RecordMediaUpload(bytes: bytes, filename: 'remove-record.png')],
      );
      await records.deleteRecord(pet.id, removableRecord.id);
      await _missing(removableRecord.mediaUrls.single);
      final photoFile = File('${directory.path}/media-community.png');
      await photoFile.writeAsBytes(bytes);
      final post = await community.createPost(
        title: '미디어 공개 사진',
        content: '실제 사진 읽기 검증',
        category: 'FREE',
        files: [XFile(photoFile.path, mimeType: 'image/png')],
      );
      final key = 'media-$stamp';
      final draft = await logs.upload(pet.id, bytes, 'draft.png', '$key-draft');
      expect(
        await logs.upload(pet.id, bytes, 'draft.png', '$key-draft'),
        draft,
      );
      final secondDraft = await logs.upload(
        pet.id,
        bytes,
        'second.png',
        '$key-second',
      );
      final created = await logs.create(pet.id, now, '미디어 반려로그', [
        draft,
        secondDraft,
      ], '$key-create');
      expect(
        (await logs.create(pet.id, now, '미디어 반려로그', [
          draft,
          secondDraft,
        ], '$key-create')).id,
        created.id,
      );
      expect(created.photos, hasLength(2));
      expect(created.photos.first.width, 40);
      expect(created.photos.first.height, 30);
      final updated = await logs.update(
        pet.id,
        created.id,
        now,
        '미디어 반려로그 유지',
        [draft],
        created.version,
        '$key-update',
      );
      expect(updated.photos, hasLength(1));
      await _missing('/api/v1/media/$secondDraft');
      final deleteDraft = await logs.upload(
        pet.id,
        bytes,
        'delete.png',
        '$key-delete-draft',
      );
      final removableLog = await logs.create(pet.id, now, '삭제할 미디어 반려로그', [
        deleteDraft,
      ], '$key-delete-create');
      final removablePost = await community.createPost(
        title: '삭제할 공개 사진',
        content: '미디어 정리 검증',
        category: 'FREE',
        files: [XFile(photoFile.path, mimeType: 'image/png')],
      );
      await community.deletePost(removablePost.id);
      await _missing(removablePost.imageUrls.single);
      final removablePet = await PetService().createPet({
        'name': '사진 정리 펫',
        'species': 'cat',
      });
      final petDraft = await logs.upload(
        removablePet.id,
        bytes,
        'pet-draft.png',
        '$key-pet-draft',
      );
      final petLogPhoto = await logs.upload(
        removablePet.id,
        bytes,
        'pet-log.png',
        '$key-pet-log',
      );
      await logs.create(removablePet.id, now, '펫 삭제 연결', [
        petLogPhoto,
      ], '$key-pet-create');
      await PetService().deletePet(removablePet.id);
      await _missing('/api/v1/media/$petDraft');
      await _missing('/api/v1/media/$petLogPhoto');
      final anonymous = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:18083'));
      try {
        final public = await anonymous.get<List<int>>(
          post.imageUrls.single,
          options: Options(responseType: ResponseType.bytes),
        );
        expect(public.data, orderedEquals(bytes));
        await expectLater(
          anonymous.get(petUrl),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'private requires auth',
              401,
            ),
          ),
        );
      } finally {
        anonymous.close();
      }
      data = {
        'petId': pet.id,
        'petUrl': petUrl,
        'profileUrl': replacement.profileImageUrl,
        'recordId': record.id,
        'recordUrl': record.mediaUrls.single,
        'postId': post.id,
        'logId': updated.id,
        'logUrl': updated.photos.single.url,
        'deleteLogId': removableLog.id,
        'deleteLogUrl': removableLog.photos.single.url,
      };
      await fixture.writeAsString(jsonEncode(data));
      debugPrint('MEDIA_API_UPLOAD_REPLACE_IDEMPOTENCY_VERIFIED');
    } else {
      data = jsonDecode(await fixture.readAsString()) as Map<String, dynamic>;
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
    final router = container.read(routerProvider);
    router.go('/my/profile');
    await _decoded(tester, data['profileUrl'] as String);
    router.go('/pet/${data['petId']}');
    await _decoded(tester, data['petUrl'] as String);
    router.go('/records/${data['recordId']}');
    await _decoded(tester, data['recordUrl'] as String);
    router.go('/community/posts/${data['postId']}');
    final postImages = find.byKey(const Key('community-detail-images'));
    await _until(tester, () => postImages.evaluate().isNotEmpty);
    await _reveal(tester, postImages);
    await _until(
      tester,
      () => find
          .descendant(
            of: postImages,
            matching: find.byWidgetPredicate(
              (w) => w is RawImage && w.image != null,
            ),
          )
          .evaluate()
          .isNotEmpty,
    );
    if (!existing) {
      final removable = await logs.get(
        data['petId'] as String,
        data['deleteLogId'] as String,
      );
      router.go('/pet-log/new', extra: removable);
      await _tap(tester, find.byKey(const Key('pet-log-edit-more')));
      await _tap(tester, find.byKey(const Key('pet-log-edit-menu-delete')));
      await _tap(tester, find.byKey(const Key('pet-log-edit-delete-confirm')));
      await _until(
        tester,
        () => find.byKey(const Key('pet-log-edit-more')).evaluate().isEmpty,
      );
      await _missing(data['deleteLogUrl'] as String);
    } else {
      await _missing(data['deleteLogUrl'] as String);
    }
    router.go('/pet-log/${data['logId']}');
    await _decoded(tester, data['logUrl'] as String);
    expect(
      (await logs.get(data['petId'] as String, data['logId'] as String)).photos,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    debugPrint(existing ? 'MEDIA_RESTART_VERIFIED' : 'MEDIA_UI_VERIFIED');
  });
}

Future<void> _missing(String url) async {
  await expectLater(
    dio.get(url),
    throwsA(
      isA<DioException>().having(
        (e) => e.response?.statusCode,
        'removed metadata',
        400,
      ),
    ),
  );
}

Future<void> _decoded(WidgetTester tester, String url) async {
  final photo = find.byWidgetPredicate(
    (w) => w is AuthenticatedNetworkImage && w.url == url,
  );
  await _until(tester, () => photo.evaluate().isNotEmpty);
  await _reveal(tester, photo);
  await _until(
    tester,
    () => find
        .descendant(
          of: photo,
          matching: find.byWidgetPredicate(
            (w) => w is RawImage && w.image != null,
          ),
        )
        .evaluate()
        .isNotEmpty,
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  await _reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: .5);
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
  fail('Media UI did not become ready');
}
