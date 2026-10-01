import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/providers/pet_provider.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../support/audit_api.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final fail in [false, true]) {
    testWidgets(
      'home restores the active pet card after a detached pager ${fail ? 'fails' : 'loads'}',
      (tester) async {
        final pending = Completer<void>();
        final api = AuditApi((request) async {
          if (request.path == '/api/v1/pets/b/records') {
            await pending.future;
            if (fail) throw Exception('offline');
            return [];
          }
          if (request.path.contains('/community/')) {
            return {'items': [], 'hasMore': false};
          }
          return auditDefaultResponse(request);
        });
        useAuditApi(api);
        final pet = PetNotifier.testWithServices(
          PetState(
            isLoading: false,
            hasOnboarded: true,
            pets: [Pet.fromJson(auditPet('a')), Pet.fromJson(auditPet('b'))],
            activePetId: 'a',
            records: const [],
            routines: const [],
            todayRoutineItems: const [],
            routineCompletions: const {},
            quickTypeIds: const [],
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [petProvider.overrideWith((_) => pet)],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('home-profile-card-a')).hitTestable(),
          findsOneWidget,
        );

        final switching = pet.setActivePet('b').catchError((_) {});
        await tester.pump();
        expect(find.byType(PageView), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        pending.complete();
        await tester.pumpAndSettle();
        await switching;

        expect(pet.state.activePetId, 'b');
        expect(
          find.byKey(const Key('home-profile-card-b')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('home-profile-card-a')).hitTestable(),
          findsNothing,
        );
        expect(
          api.requests.where((r) => r.path == '/api/v1/pets/b/records'),
          hasLength(1),
          reason: 'Restoring the selected page must not reload the same pet.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
