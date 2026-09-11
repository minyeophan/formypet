import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/app_theme.dart';
import 'package:frontend/core/app_colors.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/screens/community/write_screen.dart';
import 'package:frontend/widgets/app_icon.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
// Exercise ImagePicker itself, replacing only the native/browser picker boundary.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import '../../support/ui_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List redPng;
  late Uint8List greenPng;
  late _Picker picker;
  late _PostApi api;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    initApiClient('https://example.test', includeAuthInterceptor: false);
    redPng = await _png(Colors.red);
    greenPng = await _png(Colors.green);
  });

  setUp(() {
    final originalPicker = ImagePickerPlatform.instance;
    picker = _Picker();
    ImagePickerPlatform.instance = picker;
    addTearDown(() => ImagePickerPlatform.instance = originalPicker);
    api = _PostApi(redPng);
    dio.httpClientAdapter = api;
  });

  XFile photo(String name, [Uint8List? bytes]) => XFile.fromData(
    bytes ?? redPng,
    path: name,
    name: name,
    mimeType: 'image/png',
  );

  testWidgets('toolbar tool paints its grey surface and visible pressed ink', (
    tester,
  ) async {
    await installUiTestFonts();
    await _pump(tester);
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    final tool = find.byKey(const Key('community-add-image-button'));
    expect(tester.getSize(tool), const Size(44, 44));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: tool, matching: find.byType(RepaintBoundary)).first,
    );
    Future<Color?> sampleSurface() => tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final point = boundary.globalToLocal(
        tester.getTopLeft(tool) + const Offset(8, 8),
      );
      final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
      final color = Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
      image.dispose();
      return color;
    });
    final idle = await sampleSurface();
    expect(idle, AppColors.surfaceSoft);
    final press = await tester.startGesture(tester.getCenter(tool));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(await sampleSurface(), isNot(idle));
    await press.cancel();
    await tester.pumpAndSettle();
    expect(await sampleSurface(), idle);
  });

  for (final validOptions in [0, 1]) {
    testWidgets(
      'incomplete poll with $validOptions options blocks publishing visibly',
      (tester) async {
        await _pump(tester);
        await tester.tap(find.byKey(const Key('community-add-poll-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('community-poll-option-field-0')),
          validOptions == 1 ? '아침' : '   ',
        );
        await _submit(tester);

        expect(
          api.requests.where((request) => request.method == 'POST'),
          isEmpty,
        );
        expect(find.textContaining('2~5개'), findsWidgets);
        expect(find.textContaining('빈 항목').hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('community-poll-panel')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('community-title-field')))
              .controller!
              .text,
          '제목 수정',
        );
      },
    );
  }

  testWidgets('poll cannot add a sixth option and explains its bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester);
    await tester.tap(find.byKey(const Key('community-add-poll-button')));
    await tester.pumpAndSettle();
    final add = find.byKey(const Key('community-poll-add-option-button'));
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
    }
    expect(
      find.byKey(const Key('community-poll-option-field-5')),
      findsNothing,
    );
    expect(tester.widget<TextButton>(add).onPressed, isNull);
    expect(find.textContaining('2~5개'), findsOneWidget);
  });

  for (final count in [2, 5]) {
    testWidgets('valid $count option poll is included in publish request', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester);
      await tester.tap(find.byKey(const Key('community-add-poll-button')));
      await tester.pumpAndSettle();
      for (var i = 2; i < count; i++) {
        final add = find.byKey(const Key('community-poll-add-option-button'));
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < count; i++) {
        final field = find.byKey(Key('community-poll-option-field-$i'));
        await tester.ensureVisible(field);
        await tester.enterText(field, ' 항목 $i ');
      }
      await tester.ensureVisible(
        find.byKey(const Key('community-title-field')),
      );
      await _submit(tester);
      final data =
          api.requests.singleWhere((request) => request.method == 'POST').data
              as FormData;
      final payload = jsonDecode(
        data.fields.singleWhere((field) => field.key == 'payload').value,
      );
      expect(
        payload['poll']['options'],
        count == 2
            ? ['항목 0', '항목 1']
            : ['항목 0', '항목 1', '항목 2', '항목 3', '항목 4'],
      );
      expect(find.text('community-root'), findsOneWidget);
    });
  }

  testWidgets(
    'picker failure shows safe feedback and preserves photos for retry',
    (tester) async {
      await _pump(tester);
      picker.selections.add([photo('first.png')]);
      await _pick(tester);
      final result = Completer<List<XFile>>();
      picker.selections.add(result.future);
      await tester.tap(find.byKey(const Key('community-add-image-button')));
      await tester.pump();

      result.completeError(
        PlatformException(
          code: 'photo_access_denied',
          message: 'private-native-error-details',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('사진을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.textContaining('private-native-error-details'), findsNothing);
      expect(_railImages, findsOneWidget);
      picker.selections.add([photo('second.png')]);
      await _pick(tester);
      await _submit(tester);
      expect(_uploadedNames(api), ['first.png', 'second.png']);
    },
  );

  testWidgets('picker failure after leaving the screen is handled safely', (
    tester,
  ) async {
    await _pump(tester);
    final result = Completer<List<XFile>>();
    picker.selections.add(result.future);
    await tester.tap(find.byKey(const Key('community-add-image-button')));
    await tester.pump();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    result.completeError(PlatformException(code: 'photo_access_denied'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('community-root'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('pending upload keeps photo and poll controls disabled', (
    tester,
  ) async {
    await _pump(tester);
    final first = _DelayedReadFile(redPng);
    picker.selections.add([first, photo('second.png', greenPng)]);
    await _pick(tester);
    await tester.tap(find.byKey(const Key('community-add-poll-button')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      final option = find.byKey(Key('community-poll-option-field-$index'));
      await tester.ensureVisible(option);
      await tester.enterText(option, index == 0 ? '아침' : '저녁');
    }
    final uploadRead = Completer<Uint8List>();
    first.pendingRead = uploadRead.future;
    picker.selections.add([photo('late.png')]);
    await _startSubmit(tester);

    try {
      await tester.tap(find.byTooltip('사진 1 삭제'));
      await tester.tap(find.byKey(const Key('community-add-image-button')));
      await tester.tap(find.byKey(const Key('community-add-poll-button')));
      await tester.pump();
      expect(_railImages, findsNWidgets(2));
      expect(
        (tester.widget<Image>(_railImages.first).image as MemoryImage).bytes,
        orderedEquals(redPng),
      );
      expect(find.byKey(const Key('community-poll-panel')), findsOneWidget);
      expect(
        tester.getSemantics(find.byTooltip('사진 1 삭제')),
        isSemantics(isEnabled: false, hasTapAction: false),
      );

      final closePoll = find.byKey(const Key('community-poll-close-button'));
      await tester.ensureVisible(closePoll);
      await tester.pump();
      await tester.tap(closePoll);
      await tester.pump();
      expect(find.byKey(const Key('community-poll-panel')), findsOneWidget);
      final addOption = find.byKey(
        const Key('community-poll-add-option-button'),
      );
      await tester.ensureVisible(addOption);
      await tester.pump();
      await tester.tap(addOption);
      await tester.pump();
      expect(
        find.byKey(const Key('community-poll-option-field-2')),
        findsNothing,
      );
      final option = find.byKey(const Key('community-poll-option-field-0'));
      await tester.ensureVisible(option);
      await tester.pump();
      await tester.tap(option);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('아침'), findsOneWidget);
    } finally {
      uploadRead.complete(redPng);
      await tester.pumpAndSettle();
    }

    expect(_uploadedNames(api), ['first.png', 'second.png']);
    final form =
        api.requests.singleWhere((r) => r.method == 'POST').data as FormData;
    final payload = jsonDecode(
      form.fields.singleWhere((f) => f.key == 'payload').value,
    );
    expect(payload['poll'], {
      'question': '투표',
      'options': ['아침', '저녁'],
    });
    expect(find.text('community-root'), findsOneWidget);
  });

  testWidgets(
    'picker result arriving during submit cannot change its attachments',
    (tester) async {
      await _pump(tester);
      final first = _DelayedReadFile(redPng);
      picker.selections.add([first, photo('second.png')]);
      await _pick(tester);
      final pickResult = Completer<List<XFile>>();
      picker.selections.add(pickResult.future);
      await tester.tap(find.byKey(const Key('community-add-image-button')));
      await tester.pump();
      final uploadRead = Completer<Uint8List>();
      first.pendingRead = uploadRead.future;
      await _startSubmit(tester);

      try {
        pickResult.complete([photo('late.png')]);
        await tester.pump();
        await tester.pump();
        expect(_railImages, findsNWidgets(2));
      } finally {
        uploadRead.complete(redPng);
        await tester.pumpAndSettle();
      }

      expect(_uploadedNames(api), ['first.png', 'second.png']);
    },
  );

  testWidgets(
    'submit failure after leaving the screen does not call setState',
    (tester) async {
      await _pump(tester);
      final first = _DelayedReadFile(redPng);
      picker.selections.add([first]);
      await _pick(tester);
      final uploadRead = Completer<Uint8List>();
      first.pendingRead = uploadRead.future;
      await _startSubmit(tester);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      uploadRead.completeError(StateError('private-upload-details'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('community-root'), findsOneWidget);
      expect(find.textContaining('private-upload-details'), findsNothing);
    },
  );

  testWidgets('submit failure restores controls with safe feedback', (
    tester,
  ) async {
    await _pump(tester);
    final first = _DelayedReadFile(redPng);
    picker.selections.add([first]);
    await _pick(tester);
    final uploadRead = Completer<Uint8List>();
    first.pendingRead = uploadRead.future;
    await _startSubmit(tester);

    uploadRead.completeError(StateError('private-upload-details'));
    await tester.pumpAndSettle();

    expect(find.text('글을 등록하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('private-upload-details'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('사진 1 삭제'));
    await tester.pumpAndSettle();
    expect(_railImages, findsNothing);
    await tester.tap(find.byKey(const Key('community-add-poll-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-poll-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-add-poll-button')));
    await tester.pumpAndSettle();
    picker.selections.add([photo('retry.png')]);
    await _pick(tester);
    await _submit(tester);
    expect(_uploadedNames(api), ['retry.png']);
  });

  testWidgets(
    'selected photos render their own bytes without filesystem paths',
    (tester) async {
      await _pump(tester);
      picker.selections.add([
        photo('first.png', redPng),
        photo('second.png', greenPng),
      ]);

      await _pick(tester);

      final images = tester.widgetList<Image>(_railImages).toList();
      expect(images, hasLength(2));
      expect((images[0].image as MemoryImage).bytes, orderedEquals(redPng));
      expect((images[1].image as MemoryImage).bytes, orderedEquals(greenPng));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a second selection appends photos to the submitted post', (
    tester,
  ) async {
    await _pump(tester);
    picker.selections.addAll([
      [photo('first.png')],
      [photo('second.png')],
    ]);

    await _pick(tester);
    await _pick(tester);
    await _submit(tester);

    expect(_uploadedNames(api), ['first.png', 'second.png']);
    expect(find.text('community-root'), findsOneWidget);
  });

  testWidgets('overflow keeps the first five photos and explains the limit', (
    tester,
  ) async {
    await _pump(tester);
    picker.selections.addAll([
      [photo('1.png'), photo('2.png'), photo('3.png'), photo('4.png')],
      [photo('5.png'), photo('6.png'), photo('7.png')],
    ]);

    await _pick(tester);
    await _pick(tester);

    expect(find.textContaining('최대 5장'), findsOneWidget);
    await _submit(tester);
    expect(_uploadedNames(api), ['1.png', '2.png', '3.png', '4.png', '5.png']);
  });

  testWidgets('adding at capacity gives feedback without replacing photos', (
    tester,
  ) async {
    await _pump(tester);
    picker.selections.addAll([
      [
        photo('1.png'),
        photo('2.png'),
        photo('3.png'),
        photo('4.png'),
        photo('5.png'),
      ],
      [photo('replacement.png')],
    ]);

    await _pick(tester);
    await _pick(tester);

    expect(find.textContaining('최대 5장'), findsOneWidget);
    await _submit(tester);
    expect(_uploadedNames(api), ['1.png', '2.png', '3.png', '4.png', '5.png']);
  });

  testWidgets('cancelling another selection preserves the selected photos', (
    tester,
  ) async {
    await _pump(tester);
    picker.selections.addAll([
      [photo('first.png')],
      [],
    ]);
    await _pick(tester);
    await _pick(tester);
    await _submit(tester);

    expect(_uploadedNames(api), ['first.png']);
  });

  testWidgets(
    'photo preview and accessible removal hit distinct targets at 320px',
    (tester) async {
      _smallViewport(tester);
      await _pump(tester);
      picker.selections.add([
        photo('first.png', redPng),
        photo('second.png', greenPng),
      ]);
      await _pick(tester);
      await tester.enterText(_body, '사진과 함께 작성');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();

      final arrow = tester.widget<AppIcon>(
        find.descendant(
          of: find.byKey(const Key('community-category-field')),
          matching: find.byType(AppIcon),
        ),
      );
      expect(arrow.size, 16);
      final remove = find.byTooltip('사진 1 삭제');
      final close = tester.widget<AppIcon>(
        find.descendant(of: remove, matching: find.byType(AppIcon)),
      );
      expect(close.size, 14);
      expect(
        tester.getSize(find.byKey(const Key('community-photo-remove-disc-0'))),
        const Size(24, 24),
      );
      expect(remove.hitTestable(), findsOneWidget);
      expect(tester.getSize(remove).shortestSide, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(remove),
        isSemantics(
          tooltip: '사진 1 삭제',
          isButton: true,
          hasTapAction: true,
          isEnabled: true,
        ),
      );
      expect(
        tester.getRect(remove).contains(tester.getCenter(_railImages.first)),
        isFalse,
      );

      await tester.tap(_railImages.first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      final preview = tester.widget<Image>(
        find.descendant(of: find.byType(Dialog), matching: find.byType(Image)),
      );
      expect((preview.image as MemoryImage).bytes, orderedEquals(redPng));
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();

      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(_railImages, findsOneWidget);
      expect(
        (tester.widget<Image>(_railImages).image as MemoryImage).bytes,
        orderedEquals(greenPng),
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await _submit(tester);
      expect(_uploadedNames(api), ['second.png']);
    },
  );

  testWidgets('scrolling to remove the fifth photo frees a slot at 320px', (
    tester,
  ) async {
    _smallViewport(tester);
    await _pump(tester);
    picker.selections.addAll([
      [
        photo('1.png'),
        photo('2.png'),
        photo('3.png'),
        photo('4.png'),
        photo('5.png'),
      ],
      [photo('6.png')],
    ]);
    await _pick(tester);

    await tester.drag(
      find.byKey(const Key('community-attachment-rail')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('사진 5 삭제').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('사진 5 삭제'));
    await tester.pumpAndSettle();
    await _pick(tester);
    await _submit(tester);

    expect(_uploadedNames(api), ['1.png', '2.png', '3.png', '4.png', '6.png']);
  });

  testWidgets(
    'editing hides unsupported attachment controls and saves only text',
    (tester) async {
      final post = Post.fromJson(_postJson);
      await _pump(tester, editingPost: post);

      expect(find.byKey(const Key('community-add-image-button')), findsNothing);
      expect(find.byKey(const Key('community-add-poll-button')), findsNothing);
      expect(find.byKey(const Key('community-poll-panel')), findsNothing);
      expect(find.byTooltip('사진 1 삭제'), findsNothing);
      expect(find.textContaining('사진과 투표는 수정할 수 없어요'), findsOneWidget);
      await _submit(tester);

      final update = api.requests.singleWhere(
        (request) => request.method == 'PUT',
      );
      expect(update.path, '/api/v1/posts/post-1');
      expect(update.data, {
        'title': '제목 수정',
        'content': '내용 수정',
        'category': 'CARE',
        'petSpecies': null,
      });
      expect(
        api.requests.where((request) => request.method == 'POST'),
        isEmpty,
      );
      expect(post.imageUrls, ['/original.png']);
      expect(post.poll!.options.map((option) => option.text), ['아침', '저녁']);
      expect(find.text('community-root'), findsOneWidget);
    },
  );

  testWidgets('editing displays the existing authenticated photo preview', (
    tester,
  ) async {
    await _pump(tester, editingPost: Post.fromJson(_postJson));

    expect(_railImages, findsOneWidget);
    expect(
      (tester.widget<Image>(_railImages).image as MemoryImage).bytes,
      orderedEquals(redPng),
    );
  });

  for (final withPoll in [false, true]) {
    testWidgets('body grows with entered lines (poll: $withPoll) at 320px', (
      tester,
    ) async {
      _smallViewport(tester);
      await _pump(tester);
      if (withPoll) {
        await tester.tap(find.byKey(const Key('community-add-poll-button')));
        await tester.pumpAndSettle();
      }
      final emptyHeight = tester.getSize(_body).height;
      await tester.enterText(_body, List.filled(24, '반려동물 이야기').join('\n'));
      await tester.pumpAndSettle();

      expect(tester.getSize(_body).height, greaterThan(emptyHeight));
      final bodyScroll = tester.state<ScrollableState>(
        find.descendant(of: _body, matching: find.byType(Scrollable)),
      );
      expect(
        bodyScroll.position.maxScrollExtent,
        0,
        reason:
            'The form should scroll; a fixed-height body must not clip its lines.',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      if (withPoll) {
        final option = find.byKey(const Key('community-poll-option-field-0'));
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        expect(option.hitTestable(), findsOneWidget);
        await tester.enterText(option, '아침');
        expect(find.text('아침'), findsOneWidget);
      }
      expect(find.text('등록').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('community-add-image-button')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

final _body = find.byKey(const Key('community-content-field'));
final _railImages = find.descendant(
  of: find.byKey(const Key('community-attachment-rail')),
  matching: find.byType(Image),
);

Future<void> _pump(WidgetTester tester, {Post? editingPost}) async {
  final router = GoRouter(
    initialLocation: '/write',
    routes: [
      GoRoute(
        path: '/write',
        builder: (_, _) => WriteScreen(editingPost: editingPost),
      ),
      GoRoute(
        path: '/community',
        builder: (_, _) => const Scaffold(body: Text('community-root')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('community-add-image-button')));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await _startSubmit(tester);
  await tester.pumpAndSettle();
}

Future<void> _startSubmit(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('community-title-field')),
    '제목 수정',
  );
  await tester.enterText(_body, '내용 수정');
  await tester.tap(find.text('등록'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

List<String?> _uploadedNames(_PostApi api) {
  final request = api.requests.singleWhere(
    (request) => request.method == 'POST',
  );
  return (request.data as FormData).files
      .map((entry) => entry.value.filename)
      .toList();
}

void _smallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Future<Uint8List> _png(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  picture.dispose();
  return bytes.buffer.asUint8List();
}

class _Picker extends ImagePickerPlatform {
  final selections = <FutureOr<List<XFile>>>[];

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => selections.removeAt(0);
}

class _DelayedReadFile extends XFile {
  _DelayedReadFile(super.bytes)
    : super.fromData(path: 'first.png', mimeType: 'image/png');

  Future<Uint8List>? pendingRead;

  @override
  Future<Uint8List> readAsBytes() => pendingRead ?? super.readAsBytes();
}

class _PostApi implements HttpClientAdapter {
  _PostApi(this.photoBytes);

  final Uint8List photoBytes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/original.png' && options.method == 'GET') {
      return ResponseBody.fromBytes(photoBytes, 200);
    }
    final Object data;
    if (options.method == 'GET' && options.path == '/api/v1/posts') {
      data = {'items': [], 'nextCursor': null};
    } else if (options.method == 'POST' && options.path == '/api/v1/posts') {
      data = _postJson;
    } else if (options.method == 'PUT' &&
        options.path == '/api/v1/posts/post-1') {
      data = {..._postJson, ...options.data as Map<String, dynamic>};
    } else {
      throw StateError('Unexpected request: ${options.method} ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _postJson = {
  'id': 'post-1',
  'userId': 'user-1',
  'authorNickname': '보호자',
  'authorProfileImageUrl': null,
  'title': '원래 제목',
  'content': '원래 내용',
  'category': 'CARE',
  'likesCount': 0,
  'liked': false,
  'commentsCount': 0,
  'mediaUrls': ['/original.png'],
  'poll': {
    'id': 'poll-1',
    'question': '언제 산책하나요?',
    'options': [
      {'id': 'option-1', 'text': '아침', 'votesCount': 2, 'votedByMe': false},
      {'id': 'option-2', 'text': '저녁', 'votesCount': 1, 'votedByMe': true},
    ],
  },
  'createdAt': '2026-09-08T10:00:00',
};
