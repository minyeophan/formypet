import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/pet_log.dart';
import 'package:frontend/screens/pet_log/pet_log_export_screen.dart';
import 'package:frontend/services/pet_log_export_source.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'cancel during download returns without building an empty preview',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      initApiClient('https://cancel.test', includeAuthInterceptor: false);
      // Hold both the cover and generation download until route cancellation.
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            request.cancelToken?.whenCancel.then(handler.reject);
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PetLogExportResultScreen(
                        kind: PetLogExportKind.video,
                        photos: [
                          PetLogExportPhoto(
                            logDate: '2026-10-15',
                            photo: PetLogPhoto(
                              id: '1',
                              url: 'https://cancel.test/photo.jpg',
                              position: 0,
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('selection retained'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('selection retained'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text('제작 취소'));
      await tester.tap(find.text('제작 취소'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(TextButton, '제작 취소').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('selection retained'), findsOneWidget);
      expect(find.byType(PetLogExportResultScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
