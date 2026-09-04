import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/pet/pet_profile_form.dart';
import 'package:frontend/widgets/pet_form_fields.dart';
import 'package:frontend/widgets/authenticated_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const pet = Pet(
  id: '1',
  name: '보리',
  species: 'dog',
  birthDate: '2020-01-01',
  breed: '등록된 희귀 품종',
  adoptionDate: '2020-03-01',
  gender: 'female',
  neutered: true,
  personality: '온순함',
  diseases: '기관지염',
  weight: 4.2,
  animalRegistrationNumber: '410000000000001',
  accentColor: '#123456',
  bgLight: '#FFFFFF',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final label in ['생년월일', '함께한 날']) {
    testWidgets('$label never saves a future date', (tester) async {
      final notifier = _Notifier();
      await _pumpForm(tester, notifier);
      await enter(tester, '이름', '보리');
      final dateField = find.byWidgetPredicate(
        (w) => w is PetDateField && w.label == label,
      );
      await tester.ensureVisible(dateField);
      await tester.tap(dateField);
      await tester.pumpAndSettle();
      final pickers = tester
          .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
          .toList();
      final now = DateTime.now();
      pickers[0].onSelectedItemChanged!(now.year - 1950);
      pickers[1].onSelectedItemChanged!(11);
      pickers[2].onSelectedItemChanged!(30);
      await tester.pump();
      await tester.tap(find.byKey(const Key('record-picker-done')));
      await tester.pumpAndSettle();
      await submit(tester);
      final value =
          notifier.body?[label == '생년월일' ? 'birthDate' : 'adoptionDate']
              as String;
      expect(
        DateTime.parse(value).isAfter(DateTime(now.year, now.month, now.day)),
        isFalse,
      );
    });
  }

  testWidgets(
    'existing photo remains after picker cancellation and permission failure',
    (tester) async {
      final notifier = _Notifier(
        initialPet: pet.copyWith(profileImageUrl: '/api/v1/media/7'),
      );
      await _pumpForm(tester, notifier, editing: true);
      expect(
        tester
            .widget<AuthenticatedNetworkImage>(
              find.byType(AuthenticatedNetworkImage),
            )
            .url,
        '/api/v1/media/7',
      );
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tapText(tester, '사진 변경');
      expect(
        tester
            .widget<AuthenticatedNetworkImage>(
              find.byType(AuthenticatedNetworkImage),
            )
            .url,
        '/api/v1/media/7',
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'photo_access_denied'),
      );
      await tapText(tester, '사진 변경');
      expect(find.text('사진을 불러오지 못했어요. 사진 접근 권한을 확인해 주세요.'), findsOneWidget);
      expect(
        tester
            .widget<AuthenticatedNetworkImage>(
              find.byType(AuthenticatedNetworkImage),
            )
            .url,
        '/api/v1/media/7',
      );
    },
  );

  testWidgets(
    'create submits optional edit fields and keeps them when collapsed',
    (tester) async {
      final notifier = _Notifier();
      await _pumpForm(tester, notifier);
      await enter(tester, '이름', ' 보리 ');
      await tapText(tester, '여아');
      await tapText(tester, '완료');
      await tapText(tester, '추가 정보 (선택)');
      await enter(tester, '성격', '온순함');
      await enter(tester, '보호자 호칭', '집사');
      await enter(tester, '알러지·특이사항', '닭고기');
      await enter(tester, '주치의·병원', '동네병원');
      await tapText(tester, '추가 정보 (선택)');
      await submit(tester);
      expect(notifier.creates, 1);
      expect(notifier.body, containsPair('name', '보리'));
      expect(notifier.body, containsPair('gender', 'female'));
      expect(notifier.body, containsPair('neutered', true));
      expect(notifier.body, containsPair('personality', '온순함'));
      expect(notifier.body, containsPair('guardianNickname', '집사'));
      expect(notifier.body, containsPair('specialNotes', '닭고기'));
      expect(notifier.body, containsPair('primaryHospitalName', '동네병원'));
    },
  );

  testWidgets(
    'edit clears optional data but preserves unseen data and custom breed',
    (tester) async {
      final notifier = _Notifier();
      await _pumpForm(tester, notifier, editing: true);
      expect(find.text('성격'), findsOneWidget);
      await enter(tester, '성격', '');
      await tapText(tester, '날짜 지우기');
      await tapText(tester, '완료');
      await tapText(tester, '여아');
      await submit(tester, editing: true);
      expect(notifier.body?['personality'], isNull);
      expect(notifier.body?['adoptionDate'], isNull);
      expect(notifier.body?['neutered'], isNull);
      expect(notifier.body?['gender'], isNull);
      expect(notifier.body?['breed'], '등록된 희귀 품종');
      expect(notifier.body?['diseases'], '기관지염');
      expect(notifier.body?['weight'], 4.2);
      expect(notifier.body?['animalRegistrationNumber'], '410000000000001');
    },
  );

  testWidgets('choosing the same species preserves custom breed', (
    tester,
  ) async {
    final notifier = _Notifier();
    await _pumpForm(tester, notifier, editing: true);
    await tapText(tester, '강아지');
    await submit(tester, editing: true);
    expect(notifier.body?['breed'], '등록된 희귀 품종');
  });

  testWidgets('changing species clears only incompatible breed', (
    tester,
  ) async {
    final notifier = _Notifier();
    await _pumpForm(tester, notifier, editing: true);
    await tapText(tester, '고양이');
    await submit(tester, editing: true);
    expect(notifier.body?['breed'], isNull);
    expect(notifier.body?['species'], 'cat');
    expect(notifier.body?['personality'], '온순함');
    expect(notifier.body?['birthDate'], '2020-01-01');
  });

  testWidgets('create rejects name over 50 characters and preserves input', (
    tester,
  ) async {
    final notifier = _Notifier();
    await _pumpForm(tester, notifier);
    await enter(tester, '이름', '가' * 51);
    await submit(tester);
    expect(notifier.creates, 0);
    expect(find.text('반려동물 이름은 50자 이하로 입력해 주세요.'), findsOneWidget);
    expect(tester.widget<TextField>(field('이름')).controller!.text, '가' * 51);
  });

  testWidgets('guardian length is validated before sending', (tester) async {
    final notifier = _Notifier();
    await _pumpForm(tester, notifier);
    await enter(tester, '이름', '보리');
    await tapText(tester, '추가 정보 (선택)');
    await enter(tester, '보호자 호칭', '가' * 31);
    await submit(tester);
    expect(notifier.creates, 0);
    expect(find.text('보호자 호칭은 30자 이하로 입력해 주세요.'), findsOneWidget);
  });

  testWidgets(
    'photo partial failure retries existing pet instead of creating twice',
    (tester) async {
      final notifier = _Notifier()..failPhoto = true;
      await _pumpForm(tester, notifier);
      await enter(tester, '이름', '보리');
      await submit(tester);
      expect(find.text('사진 없이 완료'), findsOneWidget);
      await tapText(tester, '사진 없이 완료');
      expect(notifier.creates, 1);
      expect(notifier.updates, ['saved']);
    },
  );

  testWidgets('save failure preserves form for retry', (tester) async {
    final notifier = _Notifier()..failSave = true;
    await _pumpForm(tester, notifier);
    await enter(tester, '이름', '보리');
    await submit(tester);
    expect(tester.widget<TextField>(field('이름')).controller!.text, '보리');
    notifier.failSave = false;
    await submit(tester);
    expect(notifier.creates, 2);
    expect(notifier.body?['name'], '보리');
  });

  testWidgets('rapid taps send a single create request', (tester) async {
    final pending = Completer<void>();
    final notifier = _Notifier()..pending = pending.future;
    await _pumpForm(tester, notifier);
    await enter(tester, '이름', '보리');
    final button = find.widgetWithText(ElevatedButton, '등록');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.creates, 1);
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('dirty back confirms and cancel keeps edits', (tester) async {
    final notifier = _Notifier();
    await _pumpForm(tester, notifier, router: true);
    await enter(tester, '이름', '보리');
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.text('입력을 그만둘까요?'), findsOneWidget);
    await tapText(tester, '계속 입력');
    expect(tester.widget<TextField>(field('이름')).controller!.text, '보리');
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    await tapText(tester, '나가기');
    expect(find.text('my-root'), findsOneWidget);
  });

  testWidgets('additional registration goes to the created pet detail', (
    tester,
  ) async {
    final notifier = _Notifier();
    await _pumpForm(tester, notifier, router: true);
    await enter(tester, '이름', '보리');
    await submit(tester);
    expect(find.text('detail-saved'), findsOneWidget);
  });

  testWidgets(
    'three column species grid supports small screens and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpForm(tester, _Notifier(), textScale: 1.5);
      await tapText(tester, '고양이');
      expect(tester.takeException(), isNull);
      final dog = tester.getRect(find.text('강아지'));
      final cat = tester.getRect(find.text('고양이'));
      final small = tester.getRect(find.text('소동물'));
      expect(dog.top, cat.top);
      expect(cat.top, small.top);
      expect(cat.left, greaterThan(dog.left));
      expect(small.left, greaterThan(cat.left));
      await tapText(tester, '추가 정보 (선택)');
      await tapText(tester, '회복 중');
      expect(tester.takeException(), isNull);
    },
  );
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is PetTextField && w.label == label),
  matching: find.byType(TextField),
);
Future<void> enter(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester, {bool editing = false}) async {
  await tester.tap(find.widgetWithText(ElevatedButton, editing ? '저장' : '등록'));
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(
  WidgetTester tester,
  _Notifier notifier, {
  bool editing = false,
  bool router = false,
  double textScale = 1,
}) async {
  final form = PetProfileForm(petId: editing ? '1' : null);
  final routes = GoRouter(
    initialLocation: '/form',
    routes: [
      GoRoute(path: '/form', builder: (_, _) => form),
      GoRoute(
        path: '/my',
        builder: (_, _) => const Scaffold(body: Text('my-root')),
      ),
      GoRoute(
        path: '/pet/:id',
        builder: (_, s) =>
            Scaffold(body: Text('detail-${s.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(routes.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petProvider.overrideWith((ref) => notifier)],
      child: router
          ? MaterialApp.router(routerConfig: routes)
          : MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: form,
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Notifier extends PetNotifier {
  _Notifier({Pet initialPet = pet})
    : super.test(
        PetState(
          isLoading: false,
          hasOnboarded: true,
          pets: [initialPet],
          activePetId: '1',
          records: [],
          routines: [],
          todayRoutineItems: [],
          routineCompletions: {},
          quickTypeIds: [],
        ),
      );
  int creates = 0;
  final updates = <String>[];
  Map<String, dynamic>? body;
  bool failPhoto = false;
  bool failSave = false;
  Future<void>? pending;
  @override
  Future<void> addPet(
    Map<String, dynamic> body, {
    PetPhotoUpload? photo,
  }) async {
    creates++;
    this.body = body;
    if (pending != null) await pending;
    if (failSave) throw Exception('network unavailable');
    if (failPhoto) throw const PetPhotoSaveException('saved');
    state = state.copyWith(activePetId: 'saved');
  }

  @override
  Future<void> updatePet(
    String petId,
    Map<String, dynamic> body, {
    PetPhotoUpload? photo,
  }) async {
    updates.add(petId);
    this.body = body;
  }
}
