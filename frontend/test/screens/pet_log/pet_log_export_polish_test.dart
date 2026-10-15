import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/screens/pet_log/pet_log_export_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    initApiClient('https://pet-log.test', includeAuthInterceptor: false);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.method, 'GET');
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'data': {
                  'items': [
                    {
                      'id': '1',
                      'petId': '1',
                      'date': '2026-10-15',
                      'time': '12:00:00',
                      'version': 1,
                      'photos': List.generate(
                        6,
                        (i) => {
                          'id': '$i',
                          'url': 'https://pet-log.test/$i.jpg',
                          'position': i,
                          'width': 100,
                          'height': 100,
                        },
                      ),
                    },
                  ],
                  'years': [2026],
                  'hasAny': true,
                  'nextCursor': null,
                },
              },
            ),
          );
        },
      ),
    );
  });
  for (final kind in PetLogExportKind.values) {
    testWidgets(
      '${kind.name}: sixth selection shows one sheet without changing order',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: PetLogExportScreen(
              petId: '1',
              year: 2026,
              month: 10,
              all: false,
              kind: kind,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2026년 10월'), findsOneWidget);
        for (var i = 0; i < 5; i++) {
          await tester.ensureVisible(find.byKey(ValueKey('$i')));
          await tester.tap(find.byKey(ValueKey('$i')));
          await tester.pump();
        }
        await tester.ensureVisible(find.byKey(const ValueKey('5')));
        await tester.tap(find.byKey(const ValueKey('5')));
        await tester.pumpAndSettle();
        expect(find.text('기본 플랜은 사진을 최대 5장까지 선택할 수 있어요.'), findsOneWidget);
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        expect(find.textContaining('5장 선택'), findsOneWidget);
        await tester.tap(find.text('전체 해제'));
        await tester.pumpAndSettle();
        expect(find.textContaining('0장 선택'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
